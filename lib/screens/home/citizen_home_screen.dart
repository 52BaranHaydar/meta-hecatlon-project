import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:latlong2/latlong.dart';
import '../../constants/app_colors.dart';
import '../../models/ai_triage_model.dart';
import '../../services/crisis_data_service.dart';
import '../../services/language_service.dart';
import '../../models/relief_area_model.dart';
import '../../models/user_model.dart';
import '../../services/location_service.dart';
import '../../services/safety_circle_service.dart';
import '../../services/safety_sms_service.dart';

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
        _safetyCircleError = context.t(
          'Could not load your safety circle: $error',
          'Güvenlik çemberi yüklenemedi: $error',
        );
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
      locationError = LanguageService.instance.text(
        'Could not get GPS location: ${error.message}',
        'GPS konumu alınamadı: ${error.message}',
      );
    } catch (error) {
      locationError = LanguageService.instance.text(
        'Could not get GPS location: $error',
        'GPS konumu alınamadı: $error',
      );
    }

    try {
      batteryPercent = await Battery().batteryLevel;
    } catch (error) {
      batteryError = LanguageService.instance.text(
        'Could not read battery level: $error',
        'Pil seviyesi alınamadı: $error',
      );
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
        _safetyCircleError = LanguageService.instance.text(
          'Could not save your safe-status report: $error',
          'Güvende bildirimi kaydedilemedi: $error',
        );
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
            ? LanguageService.instance.text(
                'No contacts have accepted your invitation yet; your live status was not shared.',
                'Henüz daveti kabul eden yakın yok; canlı durum paylaşılmadı.',
              )
            : LanguageService.instance.text(
                'Your safety status was shared with $recipientCount contact(s).',
                'Güvenlik durumunuz $recipientCount yakınla paylaşıldı.',
              );
      } catch (error) {
        liveStatusMessage = LanguageService.instance.text(
          'Live sharing failed: $error',
          'Canlı paylaşım başarısız: $error',
        );
      }
    } else {
      liveStatusMessage = LanguageService.instance.text(
        'This report is saved on this device only and was not shared live with your contacts.',
        'Bu oturumda bildirim yalnızca bu cihazda saklanıyor; yakınlarınıza canlı iletilmedi.',
      );
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
          ? locationError ??
                LanguageService.instance.text(
                  'GPS location unavailable.',
                  'GPS konumu alınamadı.',
                )
          : LanguageService.instance.text(
              'Location and time recorded.',
              'Konum ve saat kaydedildi.',
            ),
      if (batteryPercent != null)
        LanguageService.instance.text(
          'Battery: $batteryPercent%.',
          'Pil: %$batteryPercent.',
        )
      else if (batteryError != null)
        batteryError,
      liveStatusMessage,
    ];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          LanguageService.instance.text(
            'Safe-status report saved. ${details.join(' ')}',
            'Güvende bildirimi kaydedildi. ${details.join(' ')}',
          ),
        ),
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
        _safetyCircleError = context.t(
          'Could not save blood type: $error',
          'Kan grubu kaydedilemedi: $error',
        );
      });
    }
  }

  Future<void> _confirmAndPrepareSafetySms(SafetyStatusReport report) async {
    final shouldPrepare = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.t(
            'Prepare SMS messages for your contacts?',
            'Yakınlarınıza SMS hazırlansın mı?',
          ),
        ),
        content: Text(
          context.t(
            'A separate message draft will open for each of your ${_safetyContacts.length} contact(s). '
                'You must tap Send in your messaging app. '
                'The message includes your name, blood type, GPS coordinates, and a Google Maps link. '
                'Return to the app to send the messages one by one.',
            '${_safetyContacts.length} yakının her biri için ayrı bir mesaj taslağı açılacak. '
                'Mesaj uygulamasında Gönder’e sizin basmanız gerekir. '
                'Mesajda adınız, kan grubunuz, GPS koordinatları ve Google Maps bağlantısı bulunur. '
                'Mesajları sırayla göndermek için uygulamaya dönün.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.t('Not now', 'Şimdi değil')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.t('Open SMS drafts', 'SMS taslağını aç')),
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
      setState(
        () => _smsError = context.t(
          'Submit an “I am safe” report first.',
          'Önce “Güvendeyim” bildirimi oluşturun.',
        ),
      );
      return;
    }

    await _sendNextSafetySmsDraft(safetyReport);
  }

  Future<void> _queueEmergencySms({String? reportText}) async {
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
      locationError = LanguageService.instance.text(
        'Could not get GPS location: ${error.message}',
        'GPS konumu alınamadı: ${error.message}',
      );
    } catch (error) {
      report = SafetyStatusReport(reportedAt: DateTime.now());
      locationError = LanguageService.instance.text(
        'Could not get GPS location: $error',
        'GPS konumu alınamadı: $error',
      );
    }

    try {
      final draft = await SafetySmsService.queueEmergencyMessage(
        userId: widget.user.uid,
        message: SafetySmsService.composeEmergencyMessage(
          citizenName: widget.user.name,
          reportText:
              reportText ??
              LanguageService.instance.text(
                'I need help. Emergency assistance is required.',
                'Yardım istiyorum. Acil destek gerekiyor.',
              ),
          location: locationError ?? '',
          report: report,
          english: LanguageService.instance.isEnglish,
        ),
      );
      if (!mounted) return;
      setState(() {
        _pendingEmergencySmsDrafts = [draft, ..._pendingEmergencySmsDrafts];
        _isQueueingEmergencySms = false;
        _smsError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LanguageService.instance.text(
              'Emergency SMS draft saved on this device. It has not been sent; no official destination number is configured.',
              'Acil SMS taslağı bu cihaza kaydedildi. Henüz gönderilmedi; resmî hedef numara ayarlı değil.',
            ),
          ),
          backgroundColor: AppColors.warning,
          duration: Duration(seconds: 6),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isQueueingEmergencySms = false;
        _smsError = LanguageService.instance.text(
          'Could not queue emergency SMS: $error',
          'Acil SMS kuyruğa eklenemedi: $error',
        );
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
              ListTile(
                title: Text(
                  context.t('Choose an SMS recipient', 'SMS alıcısı seçin'),
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
                title: Text(
                  context.t(
                    'Choose recipient in messaging app',
                    'Alıcıyı SMS uygulamasında seç',
                  ),
                ),
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
        setState(
          () => _smsError = context.t(
            'Could not open messaging app.',
            'SMS uygulaması açılamadı.',
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'Messaging app opened. The message will not be sent until you tap Send.',
              'SMS uygulaması açıldı. Mesaj, siz Gönder’e basana kadar gönderilmez.',
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _smsError = context.t(
          'Could not open SMS draft: $error',
          'SMS taslağı açılamadı: $error',
        ),
      );
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
      setState(
        () => _smsError = context.t(
          'Could not update SMS queue: $error',
          'SMS kuyruğu güncellenemedi: $error',
        ),
      );
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
            english: context.isEnglish,
          ),
        );
      } catch (error) {
        smsDraftError = error.toString();
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            context.t(
              'Safety circle invitation created',
              'Güvenlik ağı daveti oluşturuldu',
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                smsDraftOpened
                    ? context.t(
                        'SMS draft opened. Send the code yourself in your messaging app so your contact can accept the invitation.',
                        'SMS taslağı açıldı. Yakınınızın daveti kabul etmesi için kodu mesaj uygulamasında kendiniz gönderin.',
                      )
                    : context.t(
                        'Could not open the messaging app on this device. Share the code with your contact another way.${smsDraftError == null ? '' : '\n\nDetails: $smsDraftError'}',
                        'Bu cihazda SMS uygulaması açılamadı. Kodu yakınınıza başka bir yolla iletin.${smsDraftError == null ? '' : '\n\nAyrıntı: $smsDraftError'}',
                      ),
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
                  SnackBar(
                    content: Text(
                      context.t(
                        'Invitation code copied.',
                        'Davet kodu kopyalandı.',
                      ),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: Text(context.t('Copy code', 'Kodu kopyala')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.t('Done', 'Tamam')),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _safetyCircleError = context.t(
          'Could not create invitation: $error',
          'Davet oluşturulamadı: $error',
        ),
      );
    }
  }

  Future<void> _acceptSafetyInvite() async {
    final controller = TextEditingController();
    final inviteCode = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.t(
            'Accept safety circle invitation',
            'Güvenlik ağı davetini kabul et',
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.t(
              '32-character invitation code',
              '32 karakterli davet kodu',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.t('Cancel', 'Vazgeç')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(context.t('Accept', 'Kabul Et')),
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
          context.t(
            'You can add up to ${SafetyCircleService.maxContacts} contacts.',
            'En fazla ${SafetyCircleService.maxContacts} yakın eklenebilir.',
          ),
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
        SnackBar(
          content: Text(
            context.t(
              'Invitation accepted; mutual safety sharing is now enabled.',
              'Davet kabul edildi; karşılıklı güvenlik paylaşımı açıldı.',
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _safetyCircleError = context.t(
          'Could not accept invitation: $error',
          'Davet kabul edilemedi: $error',
        ),
      );
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
          english: context.isEnglish,
        ),
      );
      if (!mounted) return;
      if (!launched) {
        setState(() {
          _isPreparingSms = false;
          _smsError = context.t(
            'Could not open the messaging app for ${contact.name}. Make sure an SMS app is installed on your phone.',
            '${contact.name} için SMS uygulaması açılamadı. Telefonunuzda SMS uygulaması olduğundan emin olun.',
          );
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
            context.t(
              'SMS draft opened for ${contact.name}. Tap Send in your messaging app to actually send it.',
              '${contact.name} için SMS taslağı açıldı. Mesajı gerçekten göndermek için SMS uygulamasında Gönder’e basın.',
            ),
          ),
          backgroundColor: AppColors.primaryBlue,
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isPreparingSms = false;
        _smsError = context.t(
          'Could not open SMS draft: $error',
          'SMS taslağı açılamadı: $error',
        );
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
        SnackBar(
          content: Text(
            context.t(
              'This phone number is already added.',
              'Bu telefon numarası zaten ekli.',
            ),
          ),
        ),
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
        _safetyCircleError = context.t(
          'Could not add contact: $error',
          'Yakın eklenemedi: $error',
        );
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
        _safetyCircleError = context.t(
          'Could not remove contact: $error',
          'Yakın silinemedi: $error',
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_safetyCircleError!),
          backgroundColor: AppColors.emergencyRed,
        ),
      );
    }
  }

  String _areaCategoryTitle(AreaCategory category) => switch (category) {
    AreaCategory.assemblyArea => context.t('Assembly Area', 'Toplanma Alanı'),
    AreaCategory.tentCity => context.t('Tent City', 'Çadır Kent'),
    AreaCategory.hospital => context.t(
      'Field Hospital / First Aid',
      'Sahra Hastanesi / İlk Yardım',
    ),
    AreaCategory.aidStation => context.t(
      'Soup Kitchen & Water Distribution',
      'Aşevi & Su Dağıtım',
    ),
  };

  String _areaName(String name) => switch (name) {
    'Atatürk Parkı Güvenli Toplanma Alanı' => context.t(
      'Atatürk Park Safe Assembly Area',
      name,
    ),
    'Kamil Ocak 1 Nolu Çadır Kent' => context.t(
      'Kamil Ocak Tent City No. 1',
      name,
    ),
    'Kızılay Aşevi ve Temel İhtiyaç Noktası' => context.t(
      'Red Crescent Soup Kitchen and Essential Supplies Point',
      name,
    ),
    'Sahra Acil Müdahale ve İlk Yardım Merkezi' => context.t(
      'Field Emergency Response and First Aid Center',
      name,
    ),
    'Masal Parkı 2. Toplanma Bölgesi' => context.t(
      'Masal Park Assembly Area No. 2',
      name,
    ),
    _ => name,
  };

  String _areaAddress(String address) => switch (address) {
    'Şehitkamil, Osmangazi Mah. Park İçi' => context.t(
      'Şehitkamil, Osmangazi Neighborhood, inside the park',
      address,
    ),
    'Kamil Ocak Spor Kompleksi Çevresi' => context.t(
      'Around Kamil Ocak Sports Complex',
      address,
    ),
    'Mithatpaşa Meydanı Dağıtım Merkezi' => context.t(
      'Mithatpaşa Square Distribution Center',
      address,
    ),
    'İstasyon Caddesi Sağlık Çadırı' => context.t(
      'Health tent on İstasyon Street',
      address,
    ),
    'Sarıgüllük Mah. Masal Parkı İçi' => context.t(
      'Sarıgüllük Neighborhood, inside Masal Park',
      address,
    ),
    _ => address,
  };

  String _timeAgo(DateTime reportedAt) {
    final elapsed = DateTime.now().difference(reportedAt);
    if (elapsed.inMinutes < 1) {
      return context.t('Just now', 'Az önce');
    }
    if (elapsed.inHours < 1) {
      return context.t(
        '${elapsed.inMinutes} min ago',
        '${elapsed.inMinutes} dk önce',
      );
    }
    if (elapsed.inDays < 1) {
      return context.t(
        '${elapsed.inHours} hr ago',
        '${elapsed.inHours} sa önce',
      );
    }
    return context.t(
      '${elapsed.inDays} days ago',
      '${elapsed.inDays} gün önce',
    );
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
                        context.t(
                          'Hello, ${widget.user.name}',
                          'Merhaba, ${widget.user.name}',
                        ),
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
                      child: Text(
                        context.t('Citizen Portal', 'Vatandaş Portalı'),
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
                Text(
                  context.t(
                    'Are you safe? If you need help, tap the button to notify the AI-assisted disaster response center.',
                    'Güvende misiniz? Yardıma ihtiyacınız olduğunda butona basarak AI destekli afet merkezine bildirimde bulunabilirsiniz.',
                  ),
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
                        label: Text(
                          context.t('REQUEST HELP', 'YARDIM İSTE'),
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
                        label: Text(context.t('I AM SAFE', 'GÜVENDEYİM')),
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
                      children: [
                        Text(
                          context.t(
                            'Where to Go? (Map & Route)',
                            'Nereye Gitmeli? (Harita & Rota)',
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          context.t(
                            'View assembly areas and directions on the live map.',
                            'Canlı haritada toplanma alanlarını ve yol tariflerini görün.',
                          ),
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
              Text(
                context.t('Nearby Relief Areas', 'Yakın Toplanma Alanları'),
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
                child: Text(
                  context.t('View on Map', 'Haritada Aç'),
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
                Expanded(
                  child: Text(
                    context.t('Is My Family Safe?', 'Ailem Güvende mi?'),
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
            Text(
              context.t(
                'Add contacts and invite them to your safety circle. Status is shared only with people who have a real Firebase account and accepted your invitation. Reports older than 30 minutes appear as “Unreachable.”',
                'Yakın ekleyip güvenlik ağı daveti gönderin. Durumlar yalnızca gerçek Firebase hesabı bulunan ve daveti kabul eden kişilerle paylaşılır. 30 dakikadan eski bildirimler “Ulaşılamıyor” görünür.',
              ),
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
              decoration: InputDecoration(
                labelText: context.t(
                  'Your blood type (shared in SMS)',
                  'Kan grubunuz (SMS’te paylaşılır)',
                ),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              hint: Text(context.t('Select blood type', 'Kan grubu seçin')),
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
                                ? context.t(
                                    'No “I am safe” report yet.',
                                    'Henüz “Güvendeyim” bildirimi yok.',
                                  )
                                : report.latitude == null ||
                                      report.longitude == null
                                ? context.t(
                                    '[SAFE] GPS location unavailable • ${_timeAgo(report.reportedAt)}',
                                    '[GÜVENDE] GPS konumu alınamadı • ${_timeAgo(report.reportedAt)}',
                                  )
                                : context.t(
                                    '[SAFE] Location received • nearest: ${_areaName(report.placeName ?? 'Toplanma alanı bulunamadı')} • ${_timeAgo(report.reportedAt)}',
                                    '[GÜVENDE] Konum alındı • en yakın: ${report.placeName ?? 'Toplanma alanı bulunamadı'} • ${_timeAgo(report.reportedAt)}',
                                  ),
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
                              context.t(
                                'Battery: ${report!.batteryPercent}%',
                                'Pil: %${report.batteryPercent}',
                              ),
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
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    context.t(
                      'Add contacts to create your personal safety list.',
                      'Yakınlarınızı ekleyerek kişisel güvenlik listenizi oluşturun.',
                    ),
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
                              ? context.t(
                                  'Safety circle member',
                                  'Güvenlik ağı üyesi',
                                )
                              : contact.phone,
                        ),
                        trailing: IconButton(
                          tooltip: context.t('Remove contact', 'Yakını sil'),
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
                            label: Text(
                              context.t(
                                'Send safety circle invitation',
                                'Güvenlik ağı daveti gönder',
                              ),
                            ),
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
                  child: Text(
                    context.t(
                      'To send live invitations, sign out of the demo session and sign in with a real Firebase Authentication account. Invitations cannot be sent in this session.',
                      'Canlı davet için demo oturumundan çıkıp Firebase Authentication ile açılmış gerçek bir hesapla giriş yapın. Bu oturumda davet gönderilemez.',
                    ),
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
                  label: Text(
                    context.t(
                      'Accept Invitation Code',
                      'Davet Kodunu Kabul Et',
                    ),
                  ),
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
                        ? context.t(
                            'Queuing emergency SMS…',
                            'Acil SMS kuyruğa ekleniyor…',
                          )
                        : context.t(
                            'Queue help SMS offline',
                            'Yardım SMS\'ini çevrimdışı kuyruğa al',
                          ),
                  ),
                ),
              ),
              if (_pendingEmergencySmsDrafts.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.t(
                      'Pending emergency SMS drafts (${_pendingEmergencySmsDrafts.length})',
                      'Bekleyen acil SMS taslakları (${_pendingEmergencySmsDrafts.length})',
                    ),
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
                      context.t(
                        'Saved • ${draft.createdAt.toLocal()}',
                        'Kaydedildi • ${draft.createdAt.toLocal()}',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      context.t(
                        'Not sent yet; no official SMS destination is configured.',
                        'Henüz gönderilmedi; resmî SMS hedefi yapılandırılmadı.',
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      tooltip: context.t(
                        'SMS draft actions',
                        'SMS taslağı işlemleri',
                      ),
                      onSelected: (action) {
                        if (action == 'open') {
                          _openEmergencySmsDraft(draft);
                        } else if (action == 'sent') {
                          _markEmergencySmsSent(draft);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'open',
                          child: Text(
                            context.t(
                              'Open in messaging app',
                              'SMS uygulamasında aç',
                            ),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'sent',
                          child: Text(
                            context.t(
                              'Mark as sent',
                              'Gönderildi olarak işaretle',
                            ),
                          ),
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
                        ? context.t(
                            'Up to 5 contacts allowed',
                            'En fazla 5 yakın eklenebilir',
                          )
                        : context.t('Add Contact', 'Yakın Ekle'),
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
                            ? context.t('Opening SMS…', 'SMS açılıyor…')
                            : context.t(
                                'Next SMS: ${_smsQueue[_nextSmsIndex].name}',
                                'Sıradaki SMS: ${_smsQueue[_nextSmsIndex].name}',
                              ),
                      ),
                    ),
                  )
                else
                  Text(
                    context.t(
                      'All SMS drafts have been opened. Tap Send in your messaging app to send each one.',
                      'Tüm SMS taslakları açıldı. Her birini göndermek için mesaj uygulamasında Gönder’e basın.',
                    ),
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
        title: context.t('Unreachable', 'Ulaşılamıyor'),
        subtitle: inviteCode == null
            ? context.t(
                'Invitation must be accepted for live sharing.',
                'Canlı paylaşım için davet kabul edilmeli.',
              )
            : context.t(
                'This session is not authenticated with Firebase.',
                'Bu oturum Firebase ile doğrulanmadı.',
              ),
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
            title: context.t('Unreachable', 'Ulaşılamıyor'),
            subtitle: context.t(
              'Could not retrieve live status: ${snapshot.error}',
              'Canlı durum alınamadı: ${snapshot.error}',
            ),
            color: AppColors.textSecondary,
            icon: Icons.error_outline_rounded,
          );
        }
        final status = snapshot.data;
        if (status == null || !status.isReachable) {
          return _buildStatusCard(
            title: context.t('Unreachable', 'Ulaşılamıyor'),
            subtitle: status == null
                ? context.t(
                    'Waiting for invitation or no report yet.',
                    'Davet bekleniyor veya henüz bildirim yok.',
                  )
                : context.t(
                    'Last report: ${status.reportedAt.toLocal()}',
                    'Son bildirim ${status.reportedAt.toLocal()}',
                  ),
            color: AppColors.textSecondary,
            icon: Icons.signal_wifi_connected_no_internet_4_rounded,
          );
        }
        final helpRequested = status.status == SafetyStatus.helpRequested;
        return _buildStatusCard(
          title: context.t(
            helpRequested ? 'Help requested' : 'Safe',
            helpRequested ? 'Yardım İstedi' : 'Güvende',
          ),
          subtitle:
              '${status.reportedAt.toLocal()}${status.placeName == null ? '' : ' • ${_areaName(status.placeName!)}'}',
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
      label: Text(
        category == null
            ? context.t('All', 'Tümü')
            : _areaCategoryTitle(category),
      ),
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
                    _areaName(area.name),
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
                    _areaCategoryTitle(area.category),
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
              _areaAddress(area.address),
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
                  context.t(
                    'Occupancy: ${area.occupancy} / ${area.capacity} people',
                    'Kapasite: ${area.occupancy} / ${area.capacity} Kişi',
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  context.t(
                    'Available spots: ${area.availableSpots}',
                    'Boş Kontenjan: ${area.availableSpots}',
                  ),
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
                label: Text(
                  context.t(
                    'Plot Route & Go Here',
                    'Haritada Rotayı Çiz & Buraya Git',
                  ),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CitizenHelpRequestSheet(user: widget.user),
    );
  }

  @override
  void dispose() {
    _statusRefreshTimer?.cancel();
    super.dispose();
  }
}

class _CitizenHelpRequestSheet extends StatefulWidget {
  final UserModel user;

  const _CitizenHelpRequestSheet({required this.user});

  @override
  State<_CitizenHelpRequestSheet> createState() =>
      _CitizenHelpRequestSheetState();
}

class _CitizenHelpRequestSheetState extends State<_CitizenHelpRequestSheet> {
  final _textCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _crisisService = CrisisDataService();

  LatLng? _currentGps;
  bool _isLoadingGps = true;
  bool _isSubmitting = false;

  final List<Map<String, String>> _presetTemplates = [
    {
      'label': '🚨 Enkaz Altında Ses Var',
      'text':
          'Binanın 2. katında çökme var, içeride 3 kişilik bir aile ses veriyor. Acil arama kurtarma ekibi ve dinleme cihazı gerekiyor!',
      'labelEn': '🚨 Voices Under Rubble',
      'textEn':
          'A building has collapsed on the second floor. A family of three can be heard inside. Urgent search-and-rescue support and listening equipment are needed.',
    },
    {
      'label': '🩺 Acil İlaç & Medikal',
      'text':
          'Kronik kalp ve şeker hastamız var, acil insülin ve tansiyon ilacına ihtiyaç duyuyoruz. Ambulans sevk edilmeli.',
      'labelEn': '🩺 Urgent Medicine & Medical Aid',
      'textEn':
          'We have patients with chronic heart disease and diabetes who urgently need insulin and blood pressure medication. An ambulance is needed.',
    },
    {
      'label': '🍼 Bebek Maması & Su',
      'text':
          'Bulunduğumuz toplanma noktasında içme suyu tükendi ve bebekler için mama ile çocuk bezi ihtiyacımız var.',
      'labelEn': '🍼 Infant Formula & Water',
      'textEn':
          'Our assembly point has run out of drinking water. We need infant formula and diapers.',
    },
    {
      'label': '⛺ Çadır & Isıtıcı',
      'text':
          'Evimiz hasarlı ve dışarıdayız. Hava çok soğuk, 2 aile için kışlık çadır, soba ve battaniye talep ediyoruz.',
      'labelEn': '⛺ Tent & Heater',
      'textEn':
          'Our home is damaged and we are outside. It is very cold; we need winter tents, a heater, and blankets for two families.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _locationCtrl.text = context.t(
      'Central Şehitkamil, Gaziantep',
      'Şehitkamil Merkez, Gaziantep',
    );
    _fetchGpsLocation();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchGpsLocation() async {
    try {
      final loc = await LocationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _currentGps = loc;
        _isLoadingGps = false;
        _locationCtrl.text =
            'GPS: ${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)} (Şehitkamil, Gaziantep)';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingGps = false;
      });
    }
  }

  Future<void> _submitReport() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'Please enter a message describing your situation.',
              'Lütfen durumunuzu açıklayan bir mesaj yazınız.',
            ),
          ),
          backgroundColor: AppColors.emergencyRed,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _crisisService.classifyAndSubmitReport(
        text,
        location: _locationCtrl.text.trim(),
        citizenName: widget.user.name,
        citizenEmail: widget.user.email,
        citizenPhone: widget.user.phone,
        latitude: _currentGps?.latitude,
        longitude: _currentGps?.longitude,
        english: context.isEnglish,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close bottom sheet

      // Show AI Result Confirmation Dialog
      _showAiResultDialog(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'An error occurred while submitting the report: $e',
              'İhbar iletilirken bir hata oluştu: $e',
            ),
          ),
          backgroundColor: AppColors.emergencyRed,
        ),
      );
    }
  }

  String _triageCategoryTitle(String category) => switch (category) {
    'ENKAZ & ARAMA KURTARMA' => context.t(
      'Rubble & Search and Rescue',
      category,
    ),
    'ACİL SAĞLIK & MEDİKAL' => context.t(
      'Emergency Health & Medical',
      category,
    ),
    'SU, GIDA & BEBEK İHTİYACI' => context.t(
      'Water, Food & Baby Supplies',
      category,
    ),
    'BARINMA & ISINMA' => context.t('Shelter & Heating', category),
    'GENEL DESTEK & LOJİSTİK' => context.t(
      'General Support & Logistics',
      category,
    ),
    _ => category,
  };

  String _urgencyTitle(UrgencyLevel urgency) => switch (urgency) {
    UrgencyLevel.critical => context.t('CRITICAL', urgency.title),
    UrgencyLevel.high => context.t('HIGH', urgency.title),
    UrgencyLevel.medium => context.t('MEDIUM', urgency.title),
    UrgencyLevel.low => context.t('LOW', urgency.title),
  };

  void _showAiResultDialog(AiTriageResult result) {
    showDialog(
      context: context,
      builder: (dlgContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: result.urgency.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                result.urgency.icon,
                color: result.urgency.color,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('Report sent to AFAD', 'İhbar AFAD\'a İletildi'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    context.t(
                      'Meta AI Triage Report (#${result.id})',
                      'Meta AI Triyaj Raporu (#${result.id})',
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _triageCategoryTitle(result.category),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: result.urgency.color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _urgencyTitle(result.urgency),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"${result.rawText}"',
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.t(
                  'Meta AI Response Protocol:',
                  'Meta AI Müdahale Protokolü:',
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                result.recommendedAction,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.t('Requested Resources:', 'Talep Edilen Kaynaklar:'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: result.requiredResources
                    .map(
                      (res) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          res,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.t(
                          'Your report was added to the Firebase database and AFAD Crisis Desk in real time.',
                          'İhbarınız Firebase veritabanına ve AFAD Kriz Masası ekranına canlı olarak düştü.',
                        ),
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dlgContext),
            child: Text(context.t('Done', 'Tamam')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.emergencyRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.emergency_rounded,
                    color: AppColors.emergencyRed,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t(
                          'Emergency Help Request',
                          'Acil Yardım Talebi',
                        ),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        context.t(
                          'Instant triage with Meta AI Llama 3 and dispatch to AFAD',
                          'Meta AI Llama 3 ile anlık triyaj ve AFAD sevkiyatı',
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick Preset Templates
            Text(
              context.t(
                'Quick Situation Templates (Tap to select):',
                'Hızlı Durum Şablonları (Dokunarak Seçebilirsiniz):',
              ),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _presetTemplates.map((tmpl) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      label: Text(
                        context.isEnglish ? tmpl['labelEn']! : tmpl['label']!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      backgroundColor: const Color(0xFFF1F5F9),
                      onPressed: () {
                        setState(() {
                          _textCtrl.text = context.isEnglish
                              ? tmpl['textEn']!
                              : tmpl['text']!;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Text input field
            TextField(
              controller: _textCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: context.t(
                  'Describe your situation / needs',
                  'Durumunuzu / İhtiyacınızı Yazın',
                ),
                hintText: context.t(
                  'e.g. A building has collapsed on the second floor; a family of three can be heard inside...',
                  'Örn: Binanın 2. katında çökme var, içeride 3 kişilik bir aile ses veriyor...',
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.primaryBlue,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Location field
            TextField(
              controller: _locationCtrl,
              decoration: InputDecoration(
                labelText: context.t(
                  'Location / Address',
                  'Konum / Adres Bilgisi',
                ),
                prefixIcon: const Icon(
                  Icons.pin_drop_rounded,
                  color: AppColors.primaryBlue,
                ),
                suffixIcon: _isLoadingGps
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.my_location_rounded),
                        onPressed: _fetchGpsLocation,
                        tooltip: context.t(
                          'Update GPS location',
                          'GPS Konumumu Güncelle',
                        ),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emergencyRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              child: _isSubmitting
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          context.t(
                            'Meta AI is analyzing & sending to AFAD...',
                            'Meta AI Analiz Ediyor & AFAD\'a İletiyor...',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          context.t(
                            'SEND TO AFAD (AI Classification)',
                            'AFAD\'A İLET (AI Sınıflandır)',
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.t(
                        'Emergency message added to the offline SMS drafts.',
                        'Acil durum mesajı çevrimdışı SMS taslağına aktarıldı.',
                      ),
                    ),
                    backgroundColor: AppColors.primaryBlue,
                  ),
                );
              },
              icon: const Icon(Icons.sms_rounded, size: 18),
              label: Text(
                context.t(
                  'No Network? Open SMS Draft',
                  'Şebeke Yoksa: SMS Taslağı Aç',
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
      title: Text(context.t('Add Contact', 'Yakınını Ekle')),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: context.t('Name', 'Adı')),
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.t('Enter a name.', 'Ad girin.')
                  : null,
            ),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: context.t('Phone number', 'Telefon numarası'),
                hintText: '05XX XXX XX XX',
              ),
              validator: (value) {
                final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                return digits.length < 10 || digits.length > 15
                    ? context.t(
                        'Enter a valid phone number.',
                        'Geçerli bir telefon numarası girin.',
                      )
                    : null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t('Cancel', 'Vazgeç')),
        ),
        FilledButton(onPressed: _submit, child: Text(context.t('Add', 'Ekle'))),
      ],
    );
  }
}
