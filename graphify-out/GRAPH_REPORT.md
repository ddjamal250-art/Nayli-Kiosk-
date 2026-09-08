# Graph Report - lib  (2026-09-08)

## Corpus Check
- 151 files · ~176,772 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 3051 nodes · 4688 edges · 137 communities (131 shown, 6 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Community 0
- Community 1
- Community 2
- Community 3
- Community 4
- Community 5
- Community 6
- Community 7
- Community 8
- Community 9
- Community 10
- Community 11
- Community 12
- Community 13
- Community 14
- Community 15
- Community 16
- Community 17
- Community 18
- Community 19
- Community 20
- Community 21
- Community 22
- Community 23
- Community 24
- Community 25
- Community 26
- Community 27
- Community 28
- Community 29
- Community 30
- Community 31
- Community 32
- Community 33
- Community 34
- Community 35
- Community 36
- Community 37
- Community 38
- Community 39
- Community 40
- Community 41
- Community 42
- Community 43
- Community 44
- Community 45
- Community 46
- Community 47
- Community 48
- Community 49
- Community 50
- Community 51
- Community 52
- Community 53
- Community 54
- Community 55
- Community 56
- Community 57
- Community 58
- Community 59
- Community 60
- Community 61
- Community 62
- Community 63
- Community 64
- Community 65
- Community 66
- Community 67
- Community 68
- Community 69
- Community 70
- Community 71
- Community 72
- Community 73
- Community 74
- Community 75
- Community 76
- Community 77
- Community 78
- Community 79
- Community 80
- Community 81
- Community 82
- Community 83
- Community 84
- Community 85
- Community 86
- Community 87
- Community 88
- Community 89
- Community 90
- Community 91
- Community 92
- Community 93
- Community 94
- Community 95
- Community 96
- Community 97
- Community 98
- Community 99
- Community 100
- Community 101
- Community 102
- Community 103
- Community 104
- Community 105
- Community 106
- Community 107
- Community 108
- Community 109
- Community 110
- Community 111
- Community 112
- Community 113
- Community 114
- Community 115
- Community 116
- Community 117
- Community 118
- Community 119
- Community 120
- Community 121
- Community 122
- Community 123
- Community 124
- Community 125
- Community 126
- Community 127
- Community 128
- Community 129
- Community 130
- Community 131
- Community 132
- Community 133
- Community 134
- Community 135
- Community 136

## God Nodes (most connected - your core abstractions)
1. `ProductBloc` - 87 edges
2. `BillingBloc` - 72 edges
3. `CustomerCubit` - 26 edges
4. `UpdateProduct` - 24 edges
5. `ShopBloc` - 21 edges
6. `BillingEvent` - 20 edges
7. `_HomePageState` - 19 edges
8. `AddProductToCartEvent` - 18 edges
9. `LoadProducts` - 17 edges
10. `AddProduct` - 17 edges

## Surprising Connections (you probably didn't know these)
- `build` --references--> `LanguageCubit`  [EXTRACTED]
  features/billing/presentation/widgets/pos_header_toolbar.dart → core/localization/language_cubit.dart
- `_buildLangChoice` --references--> `LanguageCubit`  [EXTRACTED]
  features/settings/presentation/pages/settings_page.dart → core/localization/language_cubit.dart
- `_SettingsPageState` --references--> `LanguageCubit`  [EXTRACTED]
  features/settings/presentation/pages/settings_page.dart → core/localization/language_cubit.dart
- `build` --references--> `HeaderBrandingCubit`  [EXTRACTED]
  features/billing/presentation/widgets/header_color_dialog.dart → core/theme/header_branding_cubit.dart
- `build` --references--> `ThemeCubit`  [EXTRACTED]
  features/billing/presentation/widgets/pos_header_toolbar.dart → core/theme/theme_cubit.dart

## Import Cycles
- None detected.

## Communities (137 total, 6 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.03
Nodes (68): , barcode, charset, class, _clientsController, clientsStream, _connectedClients, costPrice (+60 more)

### Community 1 - "Community 1"
Cohesion: 0.03
Nodes (68): activeHeldCarts, address1, address2, amount, barcode, calculatedDiscount, cartItems, cartKey (+60 more)

### Community 2 - "Community 2"
Cohesion: 0.03
Nodes (65): ../../../documents/domain/entities/commercial_document.dart, ../../../documents/presentation/widgets/receipt_ocr_scanner_dialog.dart, _activeBarcode, _activeOcrIndex, _applyOcrResult, ArrivageUnitMode, build, _buildCategorySelector (+57 more)

### Community 3 - "Community 3"
Cohesion: 0.03
Nodes (61): _activePriceTier, _barcodeController, _barcodeFocusNode, build, _buildActiveModeNotice, _buildBottomHotkeysBar, _buildNumpadRow, _buildQuickItemsGrid (+53 more)

### Community 4 - "Community 4"
Cohesion: 0.04
Nodes (50): DraggableScrollableController, DraggableScrollableNotification, build, _buildCameraOffState, _buildMultiScanButton, _buildOverlayButton, _cameraZoomScale, costPrice (+42 more)

### Community 5 - "Community 5"
Cohesion: 0.04
Nodes (46): ../../../../core/utils/invoice_ocr_service.dart, ../../../../core/utils/product_image_search_service.dart, ../../../../core/utils/receipt_ocr_parser.dart, 3850, 576, _addItemManually, build, _buildItemsListTab (+38 more)

### Community 6 - "Community 6"
Cohesion: 0.04
Nodes (45): ../../../core/utils/product_image_helper.dart, ../../documents/data/commercial_document_service.dart, _analyzeCsvFile, analyzeFile, _analyzeJsonFile, _analyzeZipArchive, BackupService, BackupSnapshotInfo (+37 more)

### Community 7 - "Community 7"
Cohesion: 0.04
Nodes (44): amountPaid, barcode, CommercialDocItem, CommercialDocStatus, convertedFromId, convertedToId, copyWith, date (+36 more)

### Community 8 - "Community 8"
Cohesion: 0.05
Nodes (44): _activateOnline, build, _buildLuxuryActionCard, _buildMobileHub, _buildMobileKioskPathway, _buildMobilePairingPathway, _buildMobileStandalonePathway, _buildOfflineDouchetteTab (+36 more)

### Community 9 - "Community 9"
Cohesion: 0.05
Nodes (41): description, _generateWavBytes, getSelectedThemeId, getVolume, icon, id, isSoundEnabled, name (+33 more)

### Community 10 - "Community 10"
Cohesion: 0.11
Nodes (42): AddCustomItemEvent, ApplyDiscountEvent, BillingEvent, CleanExpiredHeldCartsEvent, ClearCartEvent, ParkCurrentCartEvent, PrintReceiptEvent, RemoveDiscountEvent (+34 more)

### Community 11 - "Community 11"
Cohesion: 0.05
Nodes (41): _addItem, _amountPaid, _amountPaidCtrl, build, _buildCurrentDoc, createState, defaultType, dispose (+33 more)

### Community 12 - "Community 12"
Cohesion: 0.05
Nodes (41): _addStockBatch, _applyMultiUnitPreset, _barcodeCtrl, _buildPresetChip, _buildProfitPill, _buildTobaccoProfitCard, _cartonPriceCtrl, categories (+33 more)

### Community 13 - "Community 13"
Cohesion: 0.05
Nodes (40): _addStockBatch, _applyMultiUnitPreset, _barcodeCtrl, _buildPresetChip, _buildProfitPill, _buildTobaccoProfitCard, _cartonPriceCtrl, categories (+32 more)

### Community 14 - "Community 14"
Cohesion: 0.05
Nodes (37): Animation, AnimationController, ../../data/kiosk_service.dart, _arrowAnimCtrl, _arrowDirection, _arrowPulse, _buffer, build (+29 more)

### Community 15 - "Community 15"
Cohesion: 0.05
Nodes (37): ../../../billing/presentation/widgets/printer_selection_dialog.dart, _addCustomLineDialog, _addressCtrl, build, _buildEditorControls, _buildItemRow, _buildReceiptPreview, _buildToggleableSection (+29 more)

### Community 16 - "Community 16"
Cohesion: 0.05
Nodes (37): attendanceBox, attendanceBoxName, commercialDocsBox, commercialDocsBoxName, customerDebtsBox, customerDebtsBoxName, customersBox, customersBoxName (+29 more)

### Community 17 - "Community 17"
Cohesion: 0.05
Nodes (36): router, ../../features/backup/presentation/pages/backup_page.dart, ../../features/billing/presentation/pages/cashier_shifts_page.dart, ../../features/billing/presentation/pages/checkout_page.dart, ../../features/billing/presentation/pages/daily_report_page.dart, ../../features/billing/presentation/pages/desktop_pos_page.dart, ../../features/billing/presentation/pages/devis_page.dart, ../../features/billing/presentation/pages/expenses_page.dart (+28 more)

### Community 18 - "Community 18"
Cohesion: 0.08
Nodes (37): CashierShiftsPage, _CashierShiftsPageState, DailyReportPage, _DailyReportPageState, DesktopPosPage, HomePage, QuickItemsManagerDialog, _QuickItemsManagerDialogState (+29 more)

### Community 19 - "Community 19"
Cohesion: 0.06
Nodes (34): hashCode, operator, read, typeId, write, barcode, cartonCostPrice, cartonPrice (+26 more)

### Community 20 - "Community 20"
Cohesion: 0.06
Nodes (33): amount, authorizationCode, _autoEcrKey, baridiPay, cardType, cash, credit, errorMessage (+25 more)

### Community 21 - "Community 21"
Cohesion: 0.06
Nodes (32): alignCenter, alignLeft, alignRight, boldOff, boldOn, checkPermission, connect, defaultDocumentPrinter (+24 more)

### Community 22 - "Community 22"
Cohesion: 0.06
Nodes (31): advanced_pos_settings_page.dart, ../../../billing/presentation/widgets/header_color_dialog.dart, ../bloc/printer_bloc.dart, ../bloc/printer_event.dart, ../bloc/printer_state.dart, ../../../../core/utils/backup_helper.dart, ../../../../core/utils/notification_service.dart, _buildBusinessHubsGrid (+23 more)

### Community 23 - "Community 23"
Cohesion: 0.06
Nodes (31): ../../../../core/utils/scale_barcode_parser.dart, _alertCooldowns, barcode, category, clearAllUnlistedScans, found, getSettings, getUnlistedScans (+23 more)

### Community 24 - "Community 24"
Cohesion: 0.06
Nodes (31): _activeRecoveryOtp, authenticate, build, _buildButton, _buildRow, createState, disablePin, _enteredPin (+23 more)

### Community 25 - "Community 25"
Cohesion: 0.14
Nodes (32): AddProduct, AdjustProductStock, BatchDeductStock, LoadProducts, ProductEvent, UpdateProduct, build, _executeRestoreOperation (+24 more)

### Community 26 - "Community 26"
Cohesion: 0.06
Nodes (31): actualCashAtClose, _box, boxName, build, _buildRow, cashDifference, cashSales, closedAt (+23 more)

### Community 27 - "Community 27"
Cohesion: 0.06
Nodes (30): enableCustomerDisplay, enableExpiryTracking, enableFastKeyboardShortcuts, enableScaleBarcode, hideCostAndProfit, isStrictStaffMode, _keyCustomerDisplay, _keyExpiryTracking (+22 more)

### Community 28 - "Community 28"
Cohesion: 0.08
Nodes (30): AddProductToCartEvent, _showQuickCustomItemModal, _addCartonToCart, _addCigarettesToCart, _addMeterToCart, _addMlToCart, _addPackToCart, build (+22 more)

### Community 29 - "Community 29"
Cohesion: 0.06
Nodes (30): DocumentType, CommercialDocument, build, _clientAddressController, _clientAiController, _clientNameController, _clientNifController, _clientNisController (+22 more)

### Community 30 - "Community 30"
Cohesion: 0.07
Nodes (29): ../../../../core/data/cloud_sync_service.dart, ../../../../core/data/local_sync_client.dart, ../../../../core/utils/merchant_context_service.dart, build, _buildInfoRow, _buildNetworkDetailsAndDiagnostics, _buildQrCard, _buildStatBox (+21 more)

### Community 31 - "Community 31"
Cohesion: 0.08
Nodes (26): AdaptiveModalHelper, ../../../../core/utils/license_service.dart, ../../../../core/utils/snackbar_helper.dart, ../../../../core/utils/sound_service.dart, ../../../../core/utils/tpe_payment_service.dart, PosPaymentModal, show, build (+18 more)

### Community 32 - "Community 32"
Cohesion: 0.07
Nodes (29): ../../../../core/utils/category_taxonomy.dart, _acompteController, _activeCategory, _addItemToInvoice, _barcodeController, build, _cartonCostController, _cartonCountController (+21 more)

### Community 33 - "Community 33"
Cohesion: 0.07
Nodes (29): ../../data/attendance_record_model.dart, ../../data/attendance_service.dart, ../../data/payroll_record_model.dart, ../../data/payroll_service.dart, ../../data/staff_member_model.dart, build, _buildAttendanceTab, _buildDialogRow (+21 more)

### Community 34 - "Community 34"
Cohesion: 0.07
Nodes (29): barcode, cartonCostPrice, cartonPrice, category, copyWith, costPrice, expiryDate, hasCarton (+21 more)

### Community 35 - "Community 35"
Cohesion: 0.07
Nodes (28): barcode, _barcodeHeight, _buildConfig, _buildInteractiveLabelPreviewCard, _categoryTabs, _clearSelection, createState, dispose (+20 more)

### Community 36 - "Community 36"
Cohesion: 0.12
Nodes (27): _onConnect, _onDisconnect, _onInit, _onRefresh, _onScan, _onTestPrint, PrinterBloc, repository (+19 more)

### Community 37 - "Community 37"
Cohesion: 0.08
Nodes (27): app_constants.dart, barcodeHeight, _buildProductStickerTemplate, _buildScaleWeightTemplate, _buildShelfTagTemplate, _buildSingleLabelContent, copyWith, currencySymbol (+19 more)

### Community 38 - "Community 38"
Cohesion: 0.10
Nodes (26): core/localization/app_localizations.dart, core/localization/language_cubit.dart, LanguageCubit, core/theme/header_branding_cubit.dart, HeaderBrandingCubit, HeaderBrandingState, core/theme/theme_cubit.dart, ThemeCubit (+18 more)

### Community 39 - "Community 39"
Cohesion: 0.07
Nodes (27): ../../../../core/utils/barcode_generator_helper.dart, ../../../../core/utils/catalog_crowdsource_helper.dart, barcode, build, costPrice, createState, _deleteItem, fromMap (+19 more)

### Community 40 - "Community 40"
Cohesion: 0.07
Nodes (27): ../../data/backup_service.dart, _analyzeAndShowRestoreDialog, _autoBackupOnShiftClose, _autoDiscoverTelegramChatId, BackupPage, _BackupPageState, _backups, _buildAnalysisStatBadge (+19 more)

### Community 41 - "Community 41"
Cohesion: 0.07
Nodes (27): _amountController, build, _buildQuickAmountChip, _buildQuickWeightChip, _categories, _costPerKgController, createState, _currentStockKg (+19 more)

### Community 42 - "Community 42"
Cohesion: 0.13
Nodes (26): Bloc, LoadShopEvent, message, ShopError, ShopEvent, ShopInitial, ShopLoaded, ShopLoading (+18 more)

### Community 43 - "Community 43"
Cohesion: 0.08
Nodes (26): ../../../../core/widgets/product_image_display.dart, SwitchCartItemUnitEvent, ../../domain/entities/cart_item.dart, _applySelection, build, _buildDisabledCard, _buildUnitOptionCard, cartItem (+18 more)

### Community 44 - "Community 44"
Cohesion: 0.08
Nodes (25): activate, _computeOfflineSignature, _computeSignature, _deviceIdKey, generateDouchetteActivationData, generateOfflineKey, getCleanMachineId, getDeviceId (+17 more)

### Community 45 - "Community 45"
Cohesion: 0.09
Nodes (25): ../../../../core/utils/shelf_label_generator.dart, DeleteProduct, _batchDelete, _categoryTabs, _categoryTabsDef, _clearSelection, _confirmDelete, createState (+17 more)

### Community 46 - "Community 46"
Cohesion: 0.08
Nodes (25): copyWith, id, items, message, newPrice, product, productId, products (+17 more)

### Community 47 - "Community 47"
Cohesion: 0.08
Nodes (25): barcode, build, costPrice, createState, date, fromMap, id, initState (+17 more)

### Community 48 - "Community 48"
Cohesion: 0.08
Nodes (25): barcode, baseSalary, can, copyWith, defaultPermissionsForRole, department, fromMap, hasPosAccess (+17 more)

### Community 49 - "Community 49"
Cohesion: 0.08
Nodes (24): ../../../billing/data/kiosk_service.dart, _buildKioskModeTab, _arrowDirection, build, _buildGuideItem, _buildNetworkEngineerTechnicalGuide, _buildTechRow, createState (+16 more)

### Community 50 - "Community 50"
Cohesion: 0.08
Nodes (24): ../../../../core/data/master_catalog_seed.dart, _applyWizardSelection, build, _buildWizardActivityCard, _clearSelection, createState, _displayLimit, dispose (+16 more)

### Community 51 - "Community 51"
Cohesion: 0.10
Nodes (21): ../../../../core/error/failure.dart, call, ../../../../core/usecase/usecase.dart, NoParams, ../../../../core/utils/app_constants.dart, ../../domain/entities/shop.dart, ../../domain/repositories/shop_repository.dart, ../error/failure.dart (+13 more)

### Community 52 - "Community 52"
Cohesion: 0.08
Nodes (24): ../../../../core/utils/commercial_pdf_generator.dart, ../../data/commercial_document_service.dart, CommercialDocType, _archiveOrUnarchive, build, _buildFilterChip, _convertDocument, createState (+16 more)

### Community 53 - "Community 53"
Cohesion: 0.08
Nodes (24): _buildCategoryTabButton, _buildMetricCard, _buildMiniStatTile, _calculateCustomerDebts, _calculateStockCapital, _calculateSupplierDebts, _calculateTotalLosses, _cashFloat (+16 more)

### Community 54 - "Community 54"
Cohesion: 0.08
Nodes (23): _allItems, _barcodeMap, _categories, categoryList, categoryNames, exportToCSV, exportToJSON, exportToSQL (+15 more)

### Community 55 - "Community 55"
Cohesion: 0.09
Nodes (22): init, sl, BackupHelper, exportDatabaseToJson, restoreDatabaseFromJson, ../features/customer/data/repositories/customer_repository.dart, features/customer/presentation/cubit/customer_cubit.dart, ../../features/product/data/models/product_model.dart (+14 more)

### Community 56 - "Community 56"
Cohesion: 0.09
Nodes (22): barcode, cartonCostPrice, cartonPrice, categories, category, defaultCost, defaultPrice, imageUrl (+14 more)

### Community 57 - "Community 57"
Cohesion: 0.09
Nodes (21): customer_state.dart, ../../data/repositories/customer_repository.dart, ../../domain/entities/customer.dart, ../../domain/entities/debt_record.dart, addCreditToCustomer, CustomerRepository, deleteCustomer, getAllCustomers (+13 more)

### Community 58 - "Community 58"
Cohesion: 0.10
Nodes (20): BuildContext, AppLocalizations, _AppLocalizationsDelegate, delegate, isSupported, load, locale, of (+12 more)

### Community 59 - "Community 59"
Cohesion: 0.10
Nodes (20): core/theme/app_theme.dart, ../../../../core/utils/printer_helper.dart, _activeShift, build, _closeShiftDialog, createState, initState, _loadShifts (+12 more)

### Community 60 - "Community 60"
Cohesion: 0.10
Nodes (19): Color, accentColor, accentColorKey, copyWith, _getInitialState, headerColor, headerColorKey, HeaderThemePreset (+11 more)

### Community 61 - "Community 61"
Cohesion: 0.11
Nodes (18): ../../../../core/utils/barcode_normalizer.dart, ../../domain/entities/product.dart, ../../domain/repositories/product_repository.dart, addProduct, adjustStock, deleteProduct, getProductByBarcode, getProducts (+10 more)

### Community 62 - "Community 62"
Cohesion: 0.10
Nodes (19): build, _buildKioskCard, _buildStationCard, currentSales, id, invoicesCount, ip, KioskInfo (+11 more)

### Community 63 - "Community 63"
Cohesion: 0.11
Nodes (18): ../../../backup/data/backup_service.dart, ../../../../core/utils/telegram_service.dart, ../../data/shift_service.dart, ../../data/staff_service.dart, CashierShift, _activeShift, _buildShiftStat, createState (+10 more)

### Community 64 - "Community 64"
Cohesion: 0.11
Nodes (18): ../bloc/shop_bloc.dart, ../../../../core/utils/app_validators.dart, ../../../../core/widgets/input_label.dart, _address1Controller, _address2Controller, build, _buildTextField, createState (+10 more)

### Community 65 - "Community 65"
Cohesion: 0.11
Nodes (18): create_edit_document_page.dart, ../../data/document_pdf_generator.dart, ../../data/document_service.dart, _allDocuments, _buildConvertTile, _buildDocumentCard, _buildStatBadge, _confirmDelete (+10 more)

### Community 66 - "Community 66"
Cohesion: 0.11
Nodes (18): ../../../customer/domain/entities/customer.dart, ../../../customer/presentation/cubit/customer_cubit.dart, ../../../customer/presentation/cubit/customer_state.dart, _acompteController, _buildCashChip, _buildDataCell, _buildHeaderCell, _buildPaymentModeChip (+10 more)

### Community 67 - "Community 67"
Cohesion: 0.11
Nodes (17): core/data/local_sync_server.dart, ../../../../core/utils/staff_permissions_service.dart, _buildSectionHeader, createState, _customerDisplay, _editScalePrefixesDialog, _expiryTracking, _fastShortcuts (+9 more)

### Community 68 - "Community 68"
Cohesion: 0.11
Nodes (17): amoledBlack, amoledBorder, amoledCard, amoledInput, amoledSurface, AppTheme, backgroundColor, darkTextTheme (+9 more)

### Community 69 - "Community 69"
Cohesion: 0.11
Nodes (17): allDomains, CategoryDomain, CategorySub, CategoryTaxonomy, domainId, domains, findDomain, getIconForCategory (+9 more)

### Community 70 - "Community 70"
Cohesion: 0.12
Nodes (16): ExcelExportHelper, exportDebtsToCsv, exportInventoryAuditToCsv, exportProductsToCsv, exportSalesLogToCsv, _getOfficialHeader, formatAlgerianPhone, generateReceiptMessage (+8 more)

### Community 71 - "Community 71"
Cohesion: 0.12
Nodes (17): ../../../../core/utils/excel_export_helper.dart, _buildFilterChip, _confirmApplyReconciliation, _countedStock, createState, dispose, _incrementCount, _initAuditData (+9 more)

### Community 72 - "Community 72"
Cohesion: 0.12
Nodes (16): _apiKeys, extractTextFromImage, instance, InvoiceOcrService, _ocrApiUrl, checkForUpdates, _hasChecked, _isRemoteNewer (+8 more)

### Community 73 - "Community 73"
Cohesion: 0.11
Nodes (17): downloadAndSaveImageLocally, _httpClient, instance, pickAndSaveImage, ProductImageSearchResult, ProductImageSearchService, _searchGoogleImages, searchImages (+9 more)

### Community 74 - "Community 74"
Cohesion: 0.11
Nodes (17): _algerianUnitDictionary, _calculateSimilarity, date, discount, entityName, _fuzzyMatchWithCatalog, items, _levenshtein (+9 more)

### Community 75 - "Community 75"
Cohesion: 0.12
Nodes (16): ../../../../core/utils/adaptive_modal_helper.dart, ../../../core/utils/online_license_service.dart, _activateOnline, build, _cityController, createState, dispose, _errorMessage (+8 more)

### Community 76 - "Community 76"
Cohesion: 0.12
Nodes (16): checkAndActivateOnline, defaultScriptUrl, firestoreApiKey, firestoreBaseUrl, firestoreProjectId, isSuccess, maxDevices, message (+8 more)

### Community 77 - "Community 77"
Cohesion: 0.12
Nodes (16): PrinterRole, build, createState, _fetchPrinters, initState, _isLoading, isSelectionOnly, _printers (+8 more)

### Community 78 - "Community 78"
Cohesion: 0.17
Nodes (16): ../../../../core/widgets/primary_button.dart, ../cubit/customer_cubit.dart, ../cubit/customer_state.dart, CustomerCubit, build, createState, CustomersPage, _CustomersPageState (+8 more)

### Community 79 - "Community 79"
Cohesion: 0.12
Nodes (16): _amountStr, build, _buildNumpadRow, _categories, createState, _defaultCategories, initState, _loadCategories (+8 more)

### Community 80 - "Community 80"
Cohesion: 0.12
Nodes (15): cloud_sync_service.dart, _autoSyncKey, getServerIp, isAutoSyncEnabled, _isConnected, LocalSyncClient, pullProductsFromMaster, pushSaleToMaster (+7 more)

### Community 81 - "Community 81"
Cohesion: 0.14
Nodes (14): CacheFailure, Failure, message, props, addressLine1, addressLine2, copyWith, footerText (+6 more)

### Community 82 - "Community 82"
Cohesion: 0.12
Nodes (15): action, amount, AuditLogEntry, AuditLogService, _boxKey, details, fromMap, getRecentLogs (+7 more)

### Community 83 - "Community 83"
Cohesion: 0.12
Nodes (15): getLiveAlerts, getLowStockThreshold, id, isNotificationsEnabled, _lowStockThresholdKey, message, _notifEnabledKey, NotificationService (+7 more)

### Community 84 - "Community 84"
Cohesion: 0.16
Nodes (13): ../bloc/billing_bloc.dart, DeleteHeldCartEvent, ResumeHeldCartEvent, ../../domain/entities/held_cart.dart, build, createState, _devisList, DevisPage (+5 more)

### Community 85 - "Community 85"
Cohesion: 0.13
Nodes (14): config/routes/app_routes.dart, core/data/master_catalog_service.dart, core/service_locator.dart, dart:ui, features/billing/presentation/bloc/billing_bloc.dart, features/settings/presentation/bloc/printer_bloc.dart, features/settings/presentation/bloc/printer_event.dart, build (+6 more)

### Community 86 - "Community 86"
Cohesion: 0.13
Nodes (14): _cloudSyncEnabledKey, CloudSyncResult, CloudSyncService, isCloudSyncEnabled, isSuccess, itemsCount, message, pairDeviceViaCloud (+6 more)

### Community 87 - "Community 87"
Cohesion: 0.18
Nodes (14): UseCase, ../entities/product.dart, AddProductUseCase, AdjustStockParams, AdjustStockUseCase, call, DeleteProductUseCase, GetProductByBarcodeUseCase (+6 more)

### Community 88 - "Community 88"
Cohesion: 0.13
Nodes (14): BarcodeNormalizer, clean, findProduct, findScaleProduct, isWeightBased, itemCode, matches, normalizeAzertyInput (+6 more)

### Community 89 - "Community 89"
Cohesion: 0.13
Nodes (14): hashCode, operator, read, typeId, write, addressLine1, addressLine2, footerText (+6 more)

### Community 90 - "Community 90"
Cohesion: 0.13
Nodes (14): dart:math, deleteStaff, findByBarcode, findByPin, generateUniquePin, getActiveCashiers, getActiveStaff, getAllStaff (+6 more)

### Community 91 - "Community 91"
Cohesion: 0.18
Nodes (14): Customer, customer, CustomerError, CustomerInitial, CustomerLoaded, CustomerLoading, CustomerOperationSuccess, customers (+6 more)

### Community 92 - "Community 92"
Cohesion: 0.13
Nodes (14): amount, date, fromMap, id, isSettled, linkedExpenseId, linkedInvoiceId, monthStr (+6 more)

### Community 93 - "Community 93"
Cohesion: 0.16
Nodes (14): @HiveType, BillingState, ProductModelAdapter, ProductState, ShopModelAdapter, Equatable, CartItem, HeldCart (+6 more)

### Community 94 - "Community 94"
Cohesion: 0.14
Nodes (12): attendance_record_model.dart, core/data/hive_database.dart, _accepted, build, createState, _decline, _eulaText, AttendanceService (+4 more)

### Community 95 - "Community 95"
Cohesion: 0.14
Nodes (13): borderRadius, build, elevation, icon, isFullWidth, isLoading, label, onPressed (+5 more)

### Community 96 - "Community 96"
Cohesion: 0.14
Nodes (13): double?, double get, cartKey, copyWith, customUnitCost, customUnitName, customUnitPrice, product (+5 more)

### Community 97 - "Community 97"
Cohesion: 0.14
Nodes (13): archiveDocument, _box, _boxName, CommercialDocumentService, convertDocument, deleteDocument, generateNextDocNumber, getDocuments (+5 more)

### Community 98 - "Community 98"
Cohesion: 0.15
Nodes (12): cart_item.dart, fromMap, id, isExpired, itemCount, items, label, parkedAt (+4 more)

### Community 99 - "Community 99"
Cohesion: 0.15
Nodes (12): daysRemaining, expiryDate, ExpiryProductInfo, ExpiryStatus, ExpiryTrackerService, getExpiringProducts, parseDate, product (+4 more)

### Community 100 - "Community 100"
Cohesion: 0.15
Nodes (12): embeddedPrice, isScaleBarcode, itemCode, parse, productCode, productCodeAlt, rawBarcode, ScaleBarcodeParser (+4 more)

### Community 101 - "Community 101"
Cohesion: 0.17
Nodes (12): ../../../core/utils/security_pin_helper.dart, build, _categories, createState, _expenses, ExpensesPage, _ExpensesPageState, initState (+4 more)

### Community 102 - "Community 102"
Cohesion: 0.15
Nodes (12): autoDiscoverChatId, defaultBotUsername, getBotToken, getChatId, getWhatsAppPhone, launchBotChat, saveSettings, sendTextMessage (+4 more)

### Community 103 - "Community 103"
Cohesion: 0.15
Nodes (12): DateTime?, AttendanceRecord, checkInTime, checkOutTime, dateStr, fromMap, id, notes (+4 more)

### Community 104 - "Community 104"
Cohesion: 0.17
Nodes (12): build, controller, _corner, createState, dispose, _isScanned, _onDetect, ScannerPage (+4 more)

### Community 105 - "Community 105"
Cohesion: 0.15
Nodes (12): address, copyWith, createdAt, currentDebt, fromMap, id, maxDebtLimit, name (+4 more)

### Community 106 - "Community 106"
Cohesion: 0.15
Nodes (12): amount, customerId, DebtTransactionType, fromMap, id, invoiceId, note, props (+4 more)

### Community 107 - "Community 107"
Cohesion: 0.17
Nodes (12): AlgerianDenominationDialog, _AlgerianDenominationDialogState, build, _buildDenomRow, _counts, createState, _increment, initialTotal (+4 more)

### Community 108 - "Community 108"
Cohesion: 0.18
Nodes (11): ../bloc/product_bloc.dart, ../../../../core/utils/expiry_tracker_service.dart, build, _buildStatBadge, createState, ExpiryMonitorPage, _ExpiryMonitorPageState, _filterStatus (+3 more)

### Community 109 - "Community 109"
Cohesion: 0.17
Nodes (11): connecting,
  connected,
  connectionFailure,
  disconnected,, connectedMac, connectedName, copyWith, devices, errorMessage, PrinterState, PrinterStatus (+3 more)

### Community 110 - "Community 110"
Cohesion: 0.17
Nodes (11): copyWith, defaultItems, fromMap, icon, id, name, price, props (+3 more)

### Community 111 - "Community 111"
Cohesion: 0.17
Nodes (11): _buildCell, _buildHeaderCell, _buildSummaryRow, CommercialPdfGenerator, exportToDesktop, exportToMobileStorage, generatePdfData, printDocument (+3 more)

### Community 112 - "Community 112"
Cohesion: 0.17
Nodes (11): PrinterHelper, ../../domain/repositories/printer_repository.dart, clearPrinterData, connect, disconnect, getSavedPrinterMac, getSavedPrinterName, _printerHelper (+3 more)

### Community 113 - "Community 113"
Cohesion: 0.17
Nodes (11): PrinterRepositoryImpl, clearPrinterData, connect, disconnect, getSavedPrinterMac, getSavedPrinterName, PrinterRepository, savePrinterData (+3 more)

### Community 114 - "Community 114"
Cohesion: 0.18
Nodes (10): AppConstants, appLogoPath, appName, currencySymbol, defaultAddressLine1, defaultAddressLine2, defaultFooterText, defaultPhoneNumber (+2 more)

### Community 115 - "Community 115"
Cohesion: 0.18
Nodes (10): getImagesDirectory, _imagesDirectory, ProductImageHelper, resolveImagePath, resolveImagePathSync, saveBase64Image, scanDirectoryForBarcodeImages, dart:io (+2 more)

### Community 116 - "Community 116"
Cohesion: 0.18
Nodes (10): ../../../core/utils/whatsapp_helper.dart, dart:typed_data, _buildPdfTotalRow, DocumentPdfGenerator, generateA4Document, printDocument, sendViaWhatsApp, package:pdf/pdf.dart (+2 more)

### Community 117 - "Community 117"
Cohesion: 0.18
Nodes (10): ../../domain/entities/commercial_document.dart, _box, boxName, convertDocument, deleteDocument, DocumentService, generateNextReference, getAllDocuments (+2 more)

### Community 118 - "Community 118"
Cohesion: 0.22
Nodes (11): build, build, _showPartnersHubSheet, Route /customers, Route /devis, Route /products/add, Route /products/catalog, Route /products/inventory-audit (+3 more)

### Community 119 - "Community 119"
Cohesion: 0.22
Nodes (11): _navigateToSettings, build, build, _buildMasterCatalogHeroBanner, _showFinanceHubSheet, Route /documents, Route /expenses, Route /master-catalog (+3 more)

### Community 120 - "Community 120"
Cohesion: 0.18
Nodes (10): build, createState, initState, _invoices, _loadInvoices, _showSettleDebtDialog, _totalDebts, _totalPurchases (+2 more)

### Community 121 - "Community 121"
Cohesion: 0.20
Nodes (9): generatePairingPayload, getMerchantId, getStoreName, MerchantContextService, _merchantIdKey, setMerchantId, _storeNameKey, license_service.dart (+1 more)

### Community 122 - "Community 122"
Cohesion: 0.20
Nodes (9): build, InputLabel, text, PrimaryButton, ProductImageDisplay, _BarcodeStripeWidget, DevicePairingModal, LivePosRadarWidget (+1 more)

### Community 123 - "Community 123"
Cohesion: 0.20
Nodes (9): borderRadius, build, _buildPlaceholder, height, imageUrl, placeholderIcon, width, IconData (+1 more)

### Community 124 - "Community 124"
Cohesion: 0.20
Nodes (9): addRecord, calculateMonthlySettlement, formatThermalPaySlip, getStaffRecords, getUnsettledRecords, PayrollService, settleMonthlySalary, package:uuid/uuid.dart (+1 more)

### Community 125 - "Community 125"
Cohesion: 0.25
Nodes (9): _handleLowStockBadgeTap, build, build, build, _showInventoryHubSheet, Route /products, Route /products/expiry-monitor, Route /products/shopping-list (+1 more)

### Community 126 - "Community 126"
Cohesion: 0.29
Nodes (6): bool get, _getInitialTheme, isAmoledDark, setTheme, themeKey, toggleTheme

### Community 127 - "Community 127"
Cohesion: 0.29
Nodes (6): CatalogCrowdsourceHelper, _kEn, silentHarvest, dart:async, dart:convert, static final List

### Community 128 - "Community 128"
Cohesion: 0.33
Nodes (5): BarcodeGeneratorHelper, calculateEan13Checksum, generateNextShortSku, generateUniqueInStoreEan13, ../data/hive_database.dart

### Community 129 - "Community 129"
Cohesion: 0.40
Nodes (4): _getInitialLocale, languageKey, setLanguage, package:flutter_bloc/flutter_bloc.dart

### Community 131 - "Community 131"
Cohesion: 0.67
Nodes (3): build, build, MaterialPageRoute

## Knowledge Gaps
- **2206 isolated node(s):** `router`, `CloudSyncResult`, `CloudSyncService`, `isSuccess`, `message` (+2201 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 2396 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `ProductBloc` connect `Community 25` to `Community 2`, `Community 3`, `Community 4`, `Community 8`, `Community 10`, `Community 12`, `Community 13`, `Community 18`, `Community 30`, `Community 32`, `Community 38`, `Community 39`, `Community 40`, `Community 41`, `Community 42`, `Community 45`, `Community 46`, `Community 47`, `Community 50`, `Community 55`, `Community 71`, `Community 85`, `Community 93`, `Community 108`, `Community 118`?**
  _High betweenness centrality (0.022) - this node is a cross-community bridge._
- **Why does `ThemeCubit` connect `Community 38` to `Community 36`, `Community 55`, `Community 22`, `Community 119`, `Community 85`, `Community 126`?**
  _High betweenness centrality (0.012) - this node is a cross-community bridge._
- **Why does `BillingBloc` connect `Community 10` to `Community 1`, `Community 66`, `Community 3`, `Community 4`, `Community 38`, `Community 41`, `Community 42`, `Community 43`, `Community 79`, `Community 84`, `Community 85`, `Community 25`, `Community 28`, `Community 93`?**
  _High betweenness centrality (0.010) - this node is a cross-community bridge._
- **What connects `router`, `CloudSyncResult`, `CloudSyncService` to the rest of the system?**
  _2206 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.028985507246376812 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.028985507246376812 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.030303030303030304 - nodes in this community are weakly interconnected._