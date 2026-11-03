import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:latlong2/latlong.dart';
import '../../constants/app_colors.dart';
import '../../models/relief_area_model.dart';
import '../../models/user_model.dart';
import '../../services/location_service.dart';
import '../../services/safety_circle_service.dart';
import '../../services/safety_sms_service.dart';
import '../../widgets/common_widgets.dart';

class CitizenHomeScreen extends StatefulWidget {
  final UserModel user;
  final void Function(ReliefAreaModel? area)? onNavigateToMap;
  final void Function(AreaCategory? category)? onNavigateToMapWithFilter;
  final void Function(LatLng? location)? onSafeReport;

  const CitizenHomeScreen({
    super.key,
    required this.user,
    this.onNavigateToMap,
    this.onNavigateToMapWithFilter,
    this.onSafeReport,
  });

  @override
  State<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends State<CitizenHomeScreen> {
  AreaCategory? _selectedCategory;
  bool _isReportingSafe = false;
  bool _hasReportedSafe = false;
  bool _isSavingContacts = false;
  bool _isLoadingSafetyCircle = true;
  bool _isPreparingSms = false;
  bool _isQueueingEmergencySms = false;
  late final SafetyCircleService _safetyCircleService;
  List<SafetyCircleContact> _safetyContacts = [];
  List<SafetyCircleContact> _smsQueue = [];
  List<SafetySmsDraft> _pendingEmergencySmsDrafts = [];
  int _nextSmsIndex = 0;
  Timer? _statusRefreshTimer;
  String? _bloodGroup;
  SafetyStatusReport? _latestSafetyReport;
  String? _safetyCircleError;
  String? _smsError;

  @override
  void initState() {
    super.initState();
    _safetyCircleService = SafetyCircleService(widget.user.uid);
    _loadSafetyCircle();
    _statusRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadSafetyCircle() async {
    try {
      final contacts = await _safetyCircleService.loadContacts();
      final report = await _safetyCircleService.loadLatestReport();
      final bloodGroup = await _safetyCircleService.loadBloodGroup();
      final smsDrafts = await SafetySmsService.loadQueue(widget.user.uid);
      if (!mounted) return;
      setState(() {
        _safetyContacts = contacts;
        _latestSafetyReport = report;
        _bloodGroup = bloodGroup;
        _pendingEmergencySmsDrafts = smsDrafts;
        _hasReportedSafe = report != null;
        _isLoadingSafetyCircle = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _safetyCircleError = 'Güvenlik çemberi yüklenemedi: $error';
        _isLoadingSafetyCircle = false;
      });
    }
  }

  List<ReliefAreaModel> get _visibleAreas => ReliefAreaModel.demoAreas
      .where(
        (area) =>
            _selectedCategory == null || area.category == _selectedCategory,
      )
      .toList();

  Future<void> _reportSafe() async {
    setState(() {
      _isReportingSafe = true;
    });

    LatLng? location;
    String? locationError;
    int? batteryPercent;
    String? batteryError;
    try {
      location = await LocationService.getCurrentLocation();
    } on LocationServiceException catch (error) {
      locationError = error.message;
    } catch (error) {
      locationError = 'GPS konumu alınamadı: $error';
    }

    try {
      batteryPercent = await Battery().batteryLevel;
    } catch (error) {
      batteryError = 'Pil seviyesi alınamadı: $error';
    }

    ReliefAreaModel? nearestArea;
    if (location != null) {
      final assemblyAreas = ReliefAreaModel.demoAreas.where(
        (area) => area.category == AreaCategory.assemblyArea && area.isSafe,
      );
      for (final area in assemblyAreas) {
        if (nearestArea == null ||
            const Distance().as(LengthUnit.Meter, location, area.location) <
                const Distance().as(
                  LengthUnit.Meter,
                  location,
                  nearestArea.location,
                )) {
          nearestArea = area;
        }
      }
    }
    final report = SafetyStatusReport(
      reportedAt: DateTime.now(),
      placeName: nearestArea?.name,
      latitude: location?.latitude,
      longitude: location?.longitude,
      batteryPercent: batteryPercent,
    );

    try {
      await _safetyCircleService.saveLatestReport(report);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isReportingSafe = false;
        _safetyCircleError = 'Güvende bildirimi kaydedilemedi: $error';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_safetyCircleError!),
          backgroundColor: AppColors.emergencyRed,
        ),
      );
      return;
    }

    if (!mounted) return;
    String? liveStatusMessage;
    if (_safetyCircleService.canUseLiveSharing(widget.user.uid)) {
      try {
        final recipientCount = await _safetyCircleService.publishStatus(
          userId: widget.user.uid,
          status: SafetyStatus.safe,
          report: report,
        );
        liveStatusMessage = recipientCount == 0
            ? 'Henüz daveti kabul eden yakın yok; canlı durum paylaşılmadı.'
            : 'Güvenlik durumunuz $recipientCount yakınla paylaşıldı.';
      } catch (error) {
        liveStatusMessage = 'Canlı paylaşım başarısız: $error';
      }
    } else {
      liveStatusMessage =
          'Bu oturumda bildirim yalnızca bu cihazda saklanıyor; yakınlarınıza canlı iletilmedi.';
    }

    if (!mounted) return;
    setState(() {
      _isReportingSafe = false;
      _hasReportedSafe = true;
      _latestSafetyReport = report;
      _safetyCircleError = liveStatusMessage;
    });
    widget.onSafeReport?.call(location);

    final details = <String>[
      location == null
          ? locationError ?? 'GPS konumu alınamadı.'
          : 'Konum ve saat kaydedildi.',
      if (batteryPercent != null)
        'Pil: %$batteryPercent.'
      else if (batteryError != null)
        batteryError,
      liveStatusMessage,
    ];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Güvende bildirimi kaydedildi. ${details.join(' ')}'),
        backgroundColor: locationError != null || batteryError != null
            ? AppColors.warning
            : AppColors.success,
      ),
    );
    if (_safetyContacts.isNotEmpty) {
      await _confirmAndPrepareSafetySms(report);
    }
  }

  Future<void> _saveBloodGroup(String bloodGroup) async {
    final oldBloodGroup = _bloodGroup;
    setState(() {
      _bloodGroup = bloodGroup;
      _safetyCircleError = null;
    });
    try {
      await _safetyCircleService.saveBloodGroup(bloodGroup);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _bloodGroup = oldBloodGroup;
        _safetyCircleError = 'Kan grubu kaydedilemedi: $error';
      });
    }
  }

  Future<void> _confirmAndPrepareSafetySms(SafetyStatusReport report) async {
    final shouldPrepare = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Yakınlarınıza SMS hazırlansın mı?'),
        content: Text(
          '${_safetyContacts.length} yakının her biri için ayrı bir mesaj taslağı açılacak. '
          'Mesaj uygulamasında Gönder’e sizin basmanız gerekir. '
          'Mesajda adınız, kan grubunuz, GPS koordinatları ve Google Maps bağlantısı bulunur. '
          'Mesajları sırayla göndermek için uygulamaya dönün.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Şimdi değil'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('SMS taslağını aç'),
          ),
        ],
      ),
    );

    if (shouldPrepare != true || !mounted) return;
    setState(() {
      _smsQueue = List.of(_safetyContacts);
      _nextSmsIndex = 0;
      _smsError = null;
    });
    await _openNextSafetySmsDraft(report);
  }

  Future<void> _openNextSafetySmsDraft([SafetyStatusReport? report]) async {
    if (_isPreparingSms || _nextSmsIndex >= _smsQueue.length) return;
    final safetyReport = report ?? _latestSafetyReport;
    if (safetyReport == null) {
      setState(() => _smsError = 'Önce “Güvendeyim” bildirimi oluşturun.');
      return;
    }

    await _sendNextSafetySmsDraft(safetyReport);
  }

  Future<void> _queueEmergencySms({
    String reportText = 'Yardım istiyorum. Acil destek gerekiyor.',
  }) async {
    if (_isQueueingEmergencySms) return;
    setState(() => _isQueueingEmergencySms = true);
    SafetyStatusReport? report;
    String? locationError;
    try {
      final location = await LocationService.getCurrentLocation();
      report = SafetyStatusReport(
        reportedAt: DateTime.now(),
        latitude: location.latitude,
        longitude: location.longitude,
      );
    } on LocationServiceException catch (error) {
      report = SafetyStatusReport(reportedAt: DateTime.now());
      locationError = error.message;
    } catch (error) {
      report = SafetyStatusReport(reportedAt: DateTime.now());
      locationError = 'GPS konumu alınamadı: $error';
    }

    try {
      final draft = await SafetySmsService.queueEmergencyMessage(
        userId: widget.user.uid,
        message: SafetySmsService.composeEmergencyMessage(
          citizenName: widget.user.name,
          reportText: reportText,
          location: locationError ?? '',
          report: report,
        ),
      );
      if (!mounted) return;
      setState(() {
        _pendingEmergencySmsDrafts = [draft, ..._pendingEmergencySmsDrafts];
        _isQueueingEmergencySms = false;
        _smsError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Acil SMS taslağı bu cihaza kaydedildi. Henüz gönderilmedi; resmî hedef numara ayarlı değil.',
          ),
          backgroundColor: AppColors.warning,
          duration: Duration(seconds: 6),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isQueueingEmergencySms = false;
        _smsError = 'Acil SMS kuyruğa eklenemedi: $error';
      });
    }
  }

  Future<void> _openEmergencySmsDraft(SafetySmsDraft draft) async {
    SafetyCircleContact? selectedContact;
    final smsContacts = _safetyContacts
        .where((contact) => contact.phone.isNotEmpty)
        .toList();
    if (smsContacts.isNotEmpty) {
      selectedContact = await showModalBottomSheet<SafetyCircleContact?>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'SMS alıcısı seçin',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              ...smsContacts.map(
                (contact) => ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(contact.name),
                  subtitle: Text(contact.phone),
                  onTap: () => Navigator.of(sheetContext).pop(contact),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Alıcıyı SMS uygulamasında seç'),
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        ),
      );
      if (!mounted) return;
    }

    try {
      final launched = selectedContact == null
          ? await SafetySmsService.openQueuedDraft(draft)
          : await SafetySmsService.openDraftToNumber(
              phone: selectedContact.phone,
              message: draft.message,
            );
      if (!mounted) return;
      if (!launched) {
        setState(() => _smsError = 'SMS uygulaması açılamadı.');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'SMS uygulaması açıldı. Mesaj, siz Gönder’e basana kadar gönderilmez.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _smsError = 'SMS taslağı açılamadı: $error');
    }
  }

  Future<void> _markEmergencySmsSent(SafetySmsDraft draft) async {
    try {
      await SafetySmsService.removeFromQueue(
        userId: widget.user.uid,
        draftId: draft.id,
      );
      if (!mounted) return;
      setState(
        () => _pendingEmergencySmsDrafts.removeWhere(
          (queued) => queued.id == draft.id,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _smsError = 'SMS kuyruğu güncellenemedi: $error');
    }
  }

  Future<void> _createSafetyInvite(SafetyCircleContact contact) async {
    try {
      final code = await _safetyCircleService.createInvite(
        userId: widget.user.uid,
        displayName: widget.user.name,
      );
      final updatedContacts = _safetyContacts
          .map(
            (saved) => saved.id == contact.id
                ? saved.copyWith(inviteCode: code)
                : saved,
          )
          .toList();
      await _safetyCircleService.saveContacts(updatedContacts);
      if (!mounted) return;
      setState(() => _safetyContacts = updatedContacts);
      var smsDraftOpened = false;
      String? smsDraftError;
      try {
        smsDraftOpened = await SafetySmsService.openDraft(
          contact: contact,
          message: SafetySmsService.composeInviteMessage(
            inviterName: widget.user.name,
            inviteCode: code,
          ),
        );
      } catch (error) {
        smsDraftError = error.toString();
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Güvenlik ağı daveti oluşturuldu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                smsDraftOpened
                    ? 'SMS taslağı açıldı. Yakınınızın daveti kabul etmesi için kodu mesaj uygulamasında kendiniz gönderin.'
                    : 'Bu cihazda SMS uygulaması açılamadı. Kodu yakınınıza başka bir yolla iletin.${smsDraftError == null ? '' : '\n\nAyrıntı: $smsDraftError'}',
              ),
              const SizedBox(height: 12),
              SelectableText(
                code,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (!mounted || !dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Davet kodu kopyalandı.')),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Kodu kopyala'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _safetyCircleError = 'Davet oluşturulamadı: $error');
    }
  }

  Future<void> _acceptSafetyInvite() async {
    final controller = TextEditingController();
    final inviteCode = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Güvenlik ağı davetini kabul et'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '32 karakterli davet kodu',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Kabul Et'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (inviteCode == null || inviteCode.isEmpty || !mounted) return;

    try {
      final normalizedCode = inviteCode.toLowerCase();
      if (_safetyContacts.length >= SafetyCircleService.maxContacts &&
          !_safetyContacts.any((contact) => contact.id == normalizedCode)) {
        throw StateError(
          'En fazla ${SafetyCircleService.maxContacts} yakın eklenebilir.',
        );
      }
      final inviterName = await _safetyCircleService.acceptInvite(
        userId: widget.user.uid,
        displayName: widget.user.name,
        inviteCode: normalizedCode,
      );
      final invitedContact = SafetyCircleContact(
        id: normalizedCode,
        name: inviterName,
        phone: '',
        inviteCode: normalizedCode,
      );
      final updatedContacts = [
        ..._safetyContacts.where((contact) => contact.id != invitedContact.id),
        invitedContact,
      ];
      await _safetyCircleService.saveContacts(updatedContacts);
      if (!mounted) return;
      setState(() {
        _safetyContacts = updatedContacts;
        _safetyCircleError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Davet kabul edildi; karşılıklı güvenlik paylaşımı açıldı.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _safetyCircleError = 'Davet kabul edilemedi: $error');
    }
  }

  Future<void> _sendNextSafetySmsDraft(SafetyStatusReport safetyReport) async {
    final contact = _smsQueue[_nextSmsIndex];
    setState(() {
      _isPreparingSms = true;
      _smsError = null;
    });
    try {
      final launched = await SafetySmsService.openDraft(
        contact: contact,
        message: SafetySmsService.composeMessage(
          citizenName: widget.user.name,
          bloodGroup: _bloodGroup,
          report: safetyReport,
        ),
      );
      if (!mounted) return;
      if (!launched) {
        setState(() {
          _isPreparingSms = false;
          _smsError =
              '${contact.name} için SMS uygulaması açılamadı. Telefonunuzda SMS uygulaması olduğundan emin olun.';
        });
        return;
      }

      setState(() {
        _nextSmsIndex++;
        _isPreparingSms = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${contact.name} için SMS taslağı açıldı. Mesajı gerçekten göndermek için SMS uygulamasında Gönder’e basın.',
          ),
          backgroundColor: AppColors.primaryBlue,
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isPreparingSms = false;
        _smsError = 'SMS taslağı açılamadı: $error';
      });
    }
  }

  Future<void> _addSafetyContact() async {
    if (_safetyContacts.length >= SafetyCircleService.maxContacts) return;

    final contact = await showDialog<SafetyCircleContact>(
      context: context,
      builder: (_) => const _SafetyContactDialog(),
    );

    if (contact == null || !mounted) return;
    final normalizedPhone = contact.phone.replaceAll(RegExp(r'\D'), '');
    if (_safetyContacts.any(
      (saved) => saved.phone.replaceAll(RegExp(r'\D'), '') == normalizedPhone,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu telefon numarası zaten ekli.')),
      );
      return;
    }

    final updatedContacts = [..._safetyContacts, contact];
    setState(() => _isSavingContacts = true);
    try {
      await _safetyCircleService.saveContacts(updatedContacts);
      if (!mounted) return;
      setState(() {
        _safetyContacts = updatedContacts;
        _isSavingContacts = false;
        _safetyCircleError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSavingContacts = false;
        _safetyCircleError = 'Yakın eklenemedi: $error';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_safetyCircleError!),
          backgroundColor: AppColors.emergencyRed,
        ),
      );
    }
  }

  Future<void> _removeSafetyContact(SafetyCircleContact contact) async {
    final updatedContacts = _safetyContacts
        .where((saved) => saved.id != contact.id)
        .toList();
    setState(() => _isSavingContacts = true);
    try {
      if (contact.inviteCode != null) {
        await _safetyCircleService.removeConnection(
          userId: widget.user.uid,
          inviteCode: contact.inviteCode!,
        );
      }
      await _safetyCircleService.saveContacts(updatedContacts);
      if (!mounted) return;
      setState(() {
        _safetyContacts = updatedContacts;
        _isSavingContacts = false;
        _safetyCircleError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSavingContacts = false;
        _safetyCircleError = 'Yakın silinemedi: $error';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_safetyCircleError!),
          backgroundColor: AppColors.emergencyRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting & Status Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Merhaba, ${widget.user.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Vatandaş Portalı',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Güvende misiniz? Yardıma ihtiyacınız olduğunda butona basarak AI destekli afet merkezine bildirimde bulunabilirsiniz.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showHelpRequestModal(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryBlue,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(
                          Icons.sos_rounded,
                          color: AppColors.emergencyRed,
                        ),
                        label: const Text(
                          'YARDIM İSTE',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isReportingSafe ? null : _reportSafe,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _isReportingSafe
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _hasReportedSafe
                                    ? Icons.verified_user_rounded
                                    : Icons.health_and_safety_rounded,
                                color: Colors.lightGreenAccent,
                                size: 18,
                              ),
                        label: const Text('GÜVENDEYİM'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _buildSafetyCircleCard(),
          const SizedBox(height: 20),

          // Big Banner: "Nereye Gitmeli? Haritada Gör"
          InkWell(
            onTap: () {
              if (widget.onNavigateToMap != null) {
                widget.onNavigateToMap!(ReliefAreaModel.demoAreas.first);
              }
            },
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.primaryBlue.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.map_rounded,
                      color: AppColors.primaryBlue,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Nereye Gitmeli? (Harita & Rota)',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Canlı haritada toplanma alanlarını ve yol tariflerini görün.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: AppColors.primaryBlue,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Quick Action Cards
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Yakın Toplanma Alanları',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () {
                  if (widget.onNavigateToMapWithFilter != null) {
                    widget.onNavigateToMapWithFilter!(_selectedCategory);
                  } else if (widget.onNavigateToMap != null) {
                    widget.onNavigateToMap!(null);
                  }
                },
                child: const Text(
                  'Haritada Aç',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _areaFilterChip(null),
                ...AreaCategory.values.map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _areaFilterChip(category),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          ..._visibleAreas.take(3).map((area) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: _buildAreaCard(context, area),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSafetyCircleCard() {
    final report = _latestSafetyReport;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.family_restroom_rounded,
                  color: AppColors.primaryBlue,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Ailem Güvende mi?',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${_safetyContacts.length}/${SafetyCircleService.maxContacts}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Yakın ekleyip güvenlik ağı daveti gönderin. Durumlar yalnızca gerçek Firebase hesabı bulunan ve daveti kabul eden kişilerle paylaşılır. 30 dakikadan eski bildirimler “Ulaşılamıyor” görünür.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey(_bloodGroup),
              initialValue: _bloodGroup,
              decoration: const InputDecoration(
                labelText: 'Kan grubunuz (SMS’te paylaşılır)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              hint: const Text('Kan grubu seçin'),
              items: SafetyCircleService.bloodGroups
                  .map(
                    (bloodGroup) => DropdownMenuItem(
                      value: bloodGroup,
                      child: Text(bloodGroup),
                    ),
                  )
                  .toList(),
              onChanged: (bloodGroup) {
                if (bloodGroup != null) _saveBloodGroup(bloodGroup);
              },
            ),
            if (_isLoadingSafetyCircle) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: report == null
                      ? AppColors.background
                      : AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: report == null
                        ? AppColors.border
                        : AppColors.success.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      report == null
                          ? Icons.info_outline_rounded
                          : Icons.verified_user_rounded,
                      color: report == null
                          ? AppColors.textSecondary
                          : AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report == null
                                ? 'Henüz “Güvendeyim” bildirimi yok.'
                                : report.latitude == null ||
                                      report.longitude == null
                                ? '[GÜVENDE] GPS konumu alınamadı • ${report.timeAgo}'
                                : '[GÜVENDE] Konum alındı • en yakın: ${report.placeName ?? 'Toplanma alanı bulunamadı'} • ${report.timeAgo}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: report == null
                                  ? AppColors.textSecondary
                                  : AppColors.success,
                            ),
                          ),
                          if (report?.batteryPercent != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Pil: %${report!.batteryPercent}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (_safetyContacts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Yakınlarınızı ekleyerek kişisel güvenlik listenizi oluşturun.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              else
                ..._safetyContacts.map(
                  (contact) => Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const CircleAvatar(
                          radius: 17,
                          child: Icon(Icons.person_outline_rounded, size: 18),
                        ),
                        title: Text(
                          contact.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          contact.phone.isEmpty
                              ? 'Güvenlik ağı üyesi'
                              : contact.phone,
                        ),
                        trailing: IconButton(
                          tooltip: 'Yakını sil',
                          onPressed: _isSavingContacts
                              ? null
                              : () => _removeSafetyContact(contact),
                          icon: const Icon(
                            Icons.remove_circle_outline_rounded,
                            color: AppColors.emergencyRed,
                          ),
                        ),
                      ),
                      _buildContactLiveStatus(contact),
                      if (contact.inviteCode == null &&
                          _safetyCircleService.canUseLiveSharing(
                            widget.user.uid,
                          ))
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _createSafetyInvite(contact),
                            icon: const Icon(Icons.send_rounded, size: 16),
                            label: const Text('Güvenlik ağı daveti gönder'),
                          ),
                        ),
                    ],
                  ),
                ),
              if (!_safetyCircleService.canUseLiveSharing(widget.user.uid))
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Text(
                    'Canlı davet için demo oturumundan çıkıp Firebase Authentication ile açılmış gerçek bir hesapla giriş yapın. Bu oturumda davet gönderilemez.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _acceptSafetyInvite,
                  icon: const Icon(Icons.group_add_rounded, size: 18),
                  label: const Text('Davet Kodunu Kabul Et'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isQueueingEmergencySms
                      ? null
                      : _queueEmergencySms,
                  icon: _isQueueingEmergencySms
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sms_outlined),
                  label: Text(
                    _isQueueingEmergencySms
                        ? 'Acil SMS kuyruğa ekleniyor…'
                        : 'Yardım SMS\'ini çevrimdışı kuyruğa al',
                  ),
                ),
              ),
              if (_pendingEmergencySmsDrafts.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Bekleyen acil SMS taslakları (${_pendingEmergencySmsDrafts.length})',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                ..._pendingEmergencySmsDrafts.map(
                  (draft) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(
                      Icons.pending_actions_rounded,
                      color: AppColors.warning,
                    ),
                    title: Text(
                      'Kaydedildi • ${draft.createdAt.toLocal()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: const Text(
                      'Henüz gönderilmedi; resmî SMS hedefi yapılandırılmadı.',
                    ),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'SMS taslağı işlemleri',
                      onSelected: (action) {
                        if (action == 'open') {
                          _openEmergencySmsDraft(draft);
                        } else if (action == 'sent') {
                          _markEmergencySmsSent(draft);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'open',
                          child: Text('SMS uygulamasında aç'),
                        ),
                        PopupMenuItem(
                          value: 'sent',
                          child: Text('Gönderildi olarak işaretle'),
                        ),
                      ],
                      child: const Icon(Icons.more_vert_rounded),
                    ),
                  ),
                ),
              ],
              if (_smsError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _smsError!,
                  style: const TextStyle(
                    color: AppColors.emergencyRed,
                    fontSize: 12,
                  ),
                ),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      _isSavingContacts ||
                          _safetyContacts.length >=
                              SafetyCircleService.maxContacts
                      ? null
                      : _addSafetyContact,
                  icon: _isSavingContacts
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: Text(
                    _safetyContacts.length >= SafetyCircleService.maxContacts
                        ? 'En fazla 5 yakın eklenebilir'
                        : 'Yakın Ekle',
                  ),
                ),
              ),
              if (_safetyCircleError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _safetyCircleError!,
                  style: const TextStyle(
                    color: AppColors.emergencyRed,
                    fontSize: 12,
                  ),
                ),
              ],
              if (_smsQueue.isNotEmpty) ...[
                const SizedBox(height: 8),
                if (_nextSmsIndex < _smsQueue.length)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isPreparingSms
                          ? null
                          : _openNextSafetySmsDraft,
                      icon: _isPreparingSms
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sms_outlined),
                      label: Text(
                        _isPreparingSms
                            ? 'SMS açılıyor…'
                            : 'Sıradaki SMS: ${_smsQueue[_nextSmsIndex].name}',
                      ),
                    ),
                  )
                else
                  const Text(
                    'Tüm SMS taslakları açıldı. Her birini göndermek için mesaj uygulamasında Gönder’e basın.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                if (_smsError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _smsError!,
                    style: const TextStyle(
                      color: AppColors.emergencyRed,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContactLiveStatus(SafetyCircleContact contact) {
    final inviteCode = contact.inviteCode;
    if (inviteCode == null ||
        !_safetyCircleService.canUseLiveSharing(widget.user.uid)) {
      return _buildStatusCard(
        title: 'Ulaşılamıyor',
        subtitle: inviteCode == null
            ? 'Canlı paylaşım için davet kabul edilmeli.'
            : 'Bu oturum Firebase ile doğrulanmadı.',
        color: AppColors.textSecondary,
        icon: Icons.signal_wifi_connected_no_internet_4_rounded,
      );
    }

    return StreamBuilder(
      stream: _safetyCircleService.watchContactStatus(
        userId: widget.user.uid,
        inviteCode: inviteCode,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildStatusCard(
            title: 'Ulaşılamıyor',
            subtitle: 'Canlı durum alınamadı: ${snapshot.error}',
            color: AppColors.textSecondary,
            icon: Icons.error_outline_rounded,
          );
        }
        final status = snapshot.data;
        if (status == null || !status.isReachable) {
          return _buildStatusCard(
            title: 'Ulaşılamıyor',
            subtitle: status == null
                ? 'Davet bekleniyor veya henüz bildirim yok.'
                : 'Son bildirim ${status.reportedAt.toLocal()}',
            color: AppColors.textSecondary,
            icon: Icons.signal_wifi_connected_no_internet_4_rounded,
          );
        }
        final helpRequested = status.status == SafetyStatus.helpRequested;
        return _buildStatusCard(
          title: helpRequested ? 'Yardım İstedi' : 'Güvende',
          subtitle:
              '${status.reportedAt.toLocal()}${status.placeName == null ? '' : ' • ${status.placeName}'}',
          color: helpRequested ? AppColors.emergencyRed : AppColors.success,
          icon: helpRequested ? Icons.sos_rounded : Icons.verified_user_rounded,
        );
      },
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _areaFilterChip(AreaCategory? category) {
    final isSelected = _selectedCategory == category;
    final color = category?.color ?? AppColors.primaryBlue;
    return FilterChip(
      selected: isSelected,
      label: Text(category?.title ?? 'Tümü'),
      avatar: Icon(category?.icon ?? Icons.dashboard_rounded, size: 16),
      selectedColor: color.withValues(alpha: 0.16),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: isSelected ? color : AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      onSelected: (_) {
        setState(() {
          _selectedCategory = category;
        });
      },
    );
  }

  Widget _buildAreaCard(BuildContext context, ReliefAreaModel area) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    area.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: area.category.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    area.category.title,
                    style: TextStyle(
                      color: area.category.color,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              area.address,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kapasite: ${area.occupancy} / ${area.capacity} Kişi',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'Boş Kontenjan: ${area.availableSpots}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (widget.onNavigateToMap != null) {
                    widget.onNavigateToMap!(area);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.navigation_rounded, size: 16),
                label: const Text(
                  'Haritada Rotayı Çiz & Buraya Git',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpRequestModal(BuildContext context) {
    final textCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: const [
                Icon(
                  Icons.report_problem_rounded,
                  color: AppColors.emergencyRed,
                ),
                SizedBox(width: 8),
                Text(
                  'Acil Yardım Talebi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Durumunuzu kısaca yazın. Meta AI mesajınızı aciliyetine göre (enkaz, sağlık, su/gıda, barınma) otomatik sınıflandıracaktır.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText:
                    'Örn: Binamızın önünde su ve bebek mamasına acil ihtiyaç var, 3 aileyiz...',
              ),
            ),
            const SizedBox(height: 16),
            CustomPrimaryButton(
              text: 'Acil SMS taslağını yerel kuyruğa ekle',
              color: AppColors.emergencyRed,
              onPressed: () async {
                final reportText = textCtrl.text.trim();
                Navigator.pop(ctx);
                await _queueEmergencySms(reportText: reportText);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _statusRefreshTimer?.cancel();
    super.dispose();
  }
}

class _SafetyContactDialog extends StatefulWidget {
  const _SafetyContactDialog();

  @override
  State<_SafetyContactDialog> createState() => _SafetyContactDialogState();
}

class _SafetyContactDialogState extends State<_SafetyContactDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      SafetyCircleContact(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yakınını Ekle'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Adı'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Ad girin.' : null,
            ),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefon numarası',
                hintText: '05XX XXX XX XX',
              ),
              validator: (value) {
                final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                return digits.length < 10 || digits.length > 15
                    ? 'Geçerli bir telefon numarası girin.'
                    : null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Ekle')),
      ],
    );
  }
}
