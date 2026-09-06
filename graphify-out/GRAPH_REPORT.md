# Graph Report - lib  (2026-09-06)

## Corpus Check
- 142 files · ~158,617 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2836 nodes · 4351 edges · 131 communities (128 shown, 3 thin omitted)
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

## God Nodes (most connected - your core abstractions)
1. `ProductBloc` - 87 edges
2. `BillingBloc` - 71 edges
3. `CustomerCubit` - 26 edges
4. `UpdateProduct` - 24 edges
5. `ShopBloc` - 21 edges
6. `BillingEvent` - 19 edges
7. `_HomePageState` - 19 edges
8. `AddProductToCartEvent` - 17 edges
9. `LoadProducts` - 17 edges
10. `AddProduct` - 17 edges

## Surprising Connections (you probably didn't know these)
- `_buildLangChoice` --references--> `LanguageCubit`  [EXTRACTED]
  features/settings/presentation/pages/settings_page.dart → core/localization/language_cubit.dart
- `_SettingsPageState` --references--> `LanguageCubit`  [EXTRACTED]
  features/settings/presentation/pages/settings_page.dart → core/localization/language_cubit.dart
- `GetShopUseCase` --implements--> `UseCase`  [EXTRACTED]
  features/shop/domain/usecases/shop_usecases.dart → core/usecase/usecase.dart
- `UpdateShopUseCase` --implements--> `UseCase`  [EXTRACTED]
  features/shop/domain/usecases/shop_usecases.dart → core/usecase/usecase.dart
- `BackupHelper` --calls--> `LoadProducts`  [EXTRACTED]
  core/utils/backup_helper.dart → features/product/presentation/bloc/product_event.dart

## Import Cycles
- None detected.

## Communities (131 total, 3 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.03
Nodes (66): , barcode, charset, class, _clientsController, clientsStream, _connectedClients, costPrice (+58 more)

### Community 1 - "Community 1"
Cohesion: 0.03
Nodes (65): ../../../documents/domain/entities/commercial_document.dart, ../../../documents/presentation/widgets/receipt_ocr_scanner_dialog.dart, _activeBarcode, _activeOcrIndex, _applyOcrResult, ArrivageUnitMode, build, _buildCategorySelector (+57 more)

### Community 2 - "Community 2"
Cohesion: 0.03
Nodes (62): _activePriceTier, _barcodeController, _barcodeFocusNode, _buildActiveModeNotice, _buildBottomHotkeysBar, _buildNumpadRow, _buildQuickItemsGrid, _buildRightCatalogPane (+54 more)

### Community 3 - "Community 3"
Cohesion: 0.03
Nodes (61): activeHeldCarts, address1, address2, amount, barcode, calculatedDiscount, cartItems, changeAmount (+53 more)

### Community 4 - "Community 4"
Cohesion: 0.04
Nodes (53): ../../../../core/utils/update_checker.dart, ../../domain/entities/cart_item.dart, DraggableScrollableController, DraggableScrollableNotification, _buildCameraOffState, _buildMultiScanButton, _buildOverlayButton, _cameraZoomScale (+45 more)

### Community 5 - "Community 5"
Cohesion: 0.06
Nodes (45): Bloc, ../bloc/shop_bloc.dart, ../../../../core/utils/app_validators.dart, ../../../../core/widgets/input_label.dart, ../../../../core/widgets/primary_button.dart, LoadShopEvent, message, ShopError (+37 more)

### Community 6 - "Community 6"
Cohesion: 0.04
Nodes (44): amountPaid, barcode, CommercialDocItem, CommercialDocStatus, convertedFromId, convertedToId, copyWith, date (+36 more)

### Community 7 - "Community 7"
Cohesion: 0.11
Nodes (43): AddProductToCartEvent, ApplyDiscountEvent, BillingEvent, CleanExpiredHeldCartsEvent, ClearCartEvent, ParkCurrentCartEvent, PrintReceiptEvent, RemoveDiscountEvent (+35 more)

### Community 8 - "Community 8"
Cohesion: 0.05
Nodes (41): description, _generateWavBytes, getSelectedThemeId, getVolume, icon, id, isSoundEnabled, name (+33 more)

### Community 9 - "Community 9"
Cohesion: 0.05
Nodes (41): _addItem, _amountPaid, _amountPaidCtrl, build, _buildCurrentDoc, createState, defaultType, dispose (+33 more)

### Community 10 - "Community 10"
Cohesion: 0.05
Nodes (37): barcode, baseSalary, can, copyWith, defaultPermissionsForRole, department, fromMap, hasPosAccess (+29 more)

### Community 11 - "Community 11"
Cohesion: 0.05
Nodes (37): ../../../billing/presentation/widgets/printer_selection_dialog.dart, _addCustomLineDialog, _addressCtrl, build, _buildEditorControls, _buildItemRow, _buildReceiptPreview, _buildToggleableSection (+29 more)

### Community 12 - "Community 12"
Cohesion: 0.05
Nodes (37): attendanceBox, attendanceBoxName, commercialDocsBox, commercialDocsBoxName, customerDebtsBox, customerDebtsBoxName, customersBox, customersBoxName (+29 more)

### Community 13 - "Community 13"
Cohesion: 0.05
Nodes (37): _addStockBatch, _barcodeCtrl, _buildProfitPill, _buildTobaccoProfitCard, _cartonPriceCtrl, categories, _costPriceCtrl, createState (+29 more)

### Community 14 - "Community 14"
Cohesion: 0.05
Nodes (36): _addStockBatch, _barcodeCtrl, _buildProfitPill, _buildTobaccoProfitCard, _cartonPriceCtrl, categories, _costPriceCtrl, createState (+28 more)

### Community 15 - "Community 15"
Cohesion: 0.06
Nodes (35): router, ../../features/backup/presentation/pages/backup_page.dart, ../../features/billing/presentation/pages/cashier_shifts_page.dart, ../../features/billing/presentation/pages/checkout_page.dart, ../../features/billing/presentation/pages/daily_report_page.dart, ../../features/billing/presentation/pages/desktop_pos_page.dart, ../../features/billing/presentation/pages/devis_page.dart, ../../features/billing/presentation/pages/expenses_page.dart (+27 more)

### Community 16 - "Community 16"
Cohesion: 0.06
Nodes (34): hashCode, operator, read, typeId, write, barcode, cartonCostPrice, cartonPrice (+26 more)

### Community 17 - "Community 17"
Cohesion: 0.06
Nodes (33): Animation, AnimationController, Color, ../../data/kiosk_service.dart, _arrowAnimCtrl, _arrowDirection, _arrowPulse, _buffer (+25 more)

### Community 18 - "Community 18"
Cohesion: 0.06
Nodes (33): actualCashAtClose, _box, boxName, build, _buildRow, cashDifference, cashSales, closedAt (+25 more)

### Community 19 - "Community 19"
Cohesion: 0.06
Nodes (32): alignCenter, alignLeft, alignRight, boldOff, boldOn, checkPermission, connect, defaultDocumentPrinter (+24 more)

### Community 20 - "Community 20"
Cohesion: 0.06
Nodes (32): _activeRecoveryOtp, authenticate, build, _buildButton, _buildRow, createState, disablePin, _enteredPin (+24 more)

### Community 21 - "Community 21"
Cohesion: 0.06
Nodes (32): DocumentType, CommercialDocument, build, _clientAddressController, _clientAiController, _clientNameController, _clientNifController, _clientNisController (+24 more)

### Community 22 - "Community 22"
Cohesion: 0.06
Nodes (31): ../../../../core/utils/scale_barcode_parser.dart, _alertCooldowns, barcode, category, clearAllUnlistedScans, found, getSettings, getUnlistedScans (+23 more)

### Community 23 - "Community 23"
Cohesion: 0.06
Nodes (31): ../../data/attendance_record_model.dart, ../../data/attendance_service.dart, ../../data/payroll_record_model.dart, ../../data/payroll_service.dart, ../../data/staff_member_model.dart, build, _buildAttendanceTab, _buildDialogRow (+23 more)

### Community 24 - "Community 24"
Cohesion: 0.06
Nodes (30): enableCustomerDisplay, enableExpiryTracking, enableFastKeyboardShortcuts, enableScaleBarcode, hideCostAndProfit, isStrictStaffMode, _keyCustomerDisplay, _keyExpiryTracking (+22 more)

### Community 25 - "Community 25"
Cohesion: 0.07
Nodes (30): amount, authorizationCode, _autoEcrKey, baridiPay, cardType, cash, credit, errorMessage (+22 more)

### Community 26 - "Community 26"
Cohesion: 0.07
Nodes (29): ../../../../core/utils/barcode_generator_helper.dart, ../../../../core/utils/catalog_crowdsource_helper.dart, barcode, build, costPrice, createState, _deleteItem, fromMap (+21 more)

### Community 27 - "Community 27"
Cohesion: 0.10
Nodes (28): ../cubit/customer_cubit.dart, ../cubit/customer_state.dart, Customer, CustomerCubit, customer, CustomerError, CustomerInitial, CustomerLoaded (+20 more)

### Community 28 - "Community 28"
Cohesion: 0.16
Nodes (30): AddProduct, AdjustProductStock, BatchDeductStock, ProductEvent, UpdateProduct, _handleQuickAddProduct, _onAddToCart, _showAddScaleProductDialog (+22 more)

### Community 29 - "Community 29"
Cohesion: 0.07
Nodes (29): LoadProducts, ../../data/backup_service.dart, _autoBackupOnShiftClose, _autoDiscoverTelegramChatId, BackupPage, _BackupPageState, _backups, build (+21 more)

### Community 30 - "Community 30"
Cohesion: 0.07
Nodes (28): ../../../../core/utils/category_taxonomy.dart, _acompteController, _activeCategory, _addItemToInvoice, _barcodeController, build, _cartonCostController, _cartonCountController (+20 more)

### Community 31 - "Community 31"
Cohesion: 0.07
Nodes (28): ../../../../core/utils/invoice_ocr_service.dart, ../../../../core/utils/receipt_ocr_parser.dart, 3850, 576, _addItemManually, build, _buildItemsListTab, _buildRawTextTab (+20 more)

### Community 32 - "Community 32"
Cohesion: 0.07
Nodes (28): barcode, _barcodeHeight, _buildConfig, _buildInteractiveLabelPreviewCard, _categoryTabs, _clearSelection, createState, dispose (+20 more)

### Community 33 - "Community 33"
Cohesion: 0.07
Nodes (27): advanced_pos_settings_page.dart, ../bloc/printer_bloc.dart, ../bloc/printer_event.dart, ../bloc/printer_state.dart, ../../../../core/utils/backup_helper.dart, ../../../../core/utils/notification_service.dart, _buildBusinessHubsGrid, _buildCardGroup (+19 more)

### Community 34 - "Community 34"
Cohesion: 0.08
Nodes (27): app_constants.dart, barcodeHeight, _buildProductStickerTemplate, _buildScaleWeightTemplate, _buildShelfTagTemplate, _buildSingleLabelContent, copyWith, currencySymbol (+19 more)

### Community 35 - "Community 35"
Cohesion: 0.08
Nodes (24): _autoSyncKey, getServerIp, isAutoSyncEnabled, _isConnected, LocalSyncClient, pullProductsFromMaster, pushSaleToMaster, _serverIpKey (+16 more)

### Community 36 - "Community 36"
Cohesion: 0.09
Nodes (23): core/localization/app_localizations.dart, ../../../../core/utils/audit_log_service.dart, ../../../../core/utils/license_service.dart, ../../../../core/utils/snackbar_helper.dart, ../../../../core/utils/sound_service.dart, ../../../../core/utils/tpe_payment_service.dart, build, text (+15 more)

### Community 37 - "Community 37"
Cohesion: 0.08
Nodes (26): _buildCategoryTabButton, _buildMetricCard, _buildMiniStatTile, _calculateCustomerDebts, _calculateStockCapital, _calculateSupplierDebts, _calculateTotalLosses, _cashFloat (+18 more)

### Community 38 - "Community 38"
Cohesion: 0.07
Nodes (26): barcode, cartonCostPrice, cartonPrice, category, copyWith, costPrice, expiryDate, id (+18 more)

### Community 39 - "Community 39"
Cohesion: 0.08
Nodes (26): build, _buildInfoRow, _buildNetworkDetailsAndDiagnostics, _buildQrCard, _buildStatBox, _connectedMasterIp, _connectedMasterPort, _connectedShopName (+18 more)

### Community 40 - "Community 40"
Cohesion: 0.09
Nodes (25): ../../../../core/utils/shelf_label_generator.dart, DeleteProduct, _batchDelete, _categoryTabs, _categoryTabsDef, _clearSelection, _confirmDelete, createState (+17 more)

### Community 41 - "Community 41"
Cohesion: 0.08
Nodes (25): copyWith, id, items, message, newPrice, product, productId, products (+17 more)

### Community 42 - "Community 42"
Cohesion: 0.08
Nodes (25): _amountController, build, _buildQuickAmountChip, _buildQuickWeightChip, _categories, _costPerKgController, createState, _currentStockKg (+17 more)

### Community 43 - "Community 43"
Cohesion: 0.08
Nodes (24): ../../../billing/data/kiosk_service.dart, _arrowDirection, build, _buildGuideItem, _buildNetworkEngineerTechnicalGuide, _buildTechRow, createState, _displayDuration (+16 more)

### Community 44 - "Community 44"
Cohesion: 0.10
Nodes (21): ../../../../core/error/failure.dart, call, ../../../../core/usecase/usecase.dart, NoParams, ../../../../core/utils/app_constants.dart, ../../domain/entities/shop.dart, ../../domain/repositories/shop_repository.dart, ../error/failure.dart (+13 more)

### Community 45 - "Community 45"
Cohesion: 0.08
Nodes (24): barcode, build, costPrice, createState, date, fromMap, id, initState (+16 more)

### Community 46 - "Community 46"
Cohesion: 0.09
Nodes (22): config/routes/app_routes.dart, core/data/master_catalog_service.dart, core/localization/language_cubit.dart, _getInitialLocale, LanguageCubit, languageKey, setLanguage, core/service_locator.dart (+14 more)

### Community 47 - "Community 47"
Cohesion: 0.09
Nodes (23): build, _buildCartonTab, _buildCigaretteTab, _buildMeterTab, _buildMlTab, _buildPackTab, _cartonQty, _cigaretteCount (+15 more)

### Community 48 - "Community 48"
Cohesion: 0.10
Nodes (21): BuildContext, AppLocalizations, _AppLocalizationsDelegate, delegate, isSupported, load, locale, of (+13 more)

### Community 49 - "Community 49"
Cohesion: 0.09
Nodes (22): barcode, cartonCostPrice, cartonPrice, categories, category, defaultCost, defaultPrice, imageUrl (+14 more)

### Community 50 - "Community 50"
Cohesion: 0.09
Nodes (22): _allItems, _barcodeMap, _categories, categoryList, categoryNames, exportToCSV, exportToJSON, exportToSQL (+14 more)

### Community 51 - "Community 51"
Cohesion: 0.09
Nodes (21): init, sl, BackupHelper, exportDatabaseToJson, restoreDatabaseFromJson, ../features/customer/data/repositories/customer_repository.dart, features/customer/presentation/cubit/customer_cubit.dart, ../../features/product/data/models/product_model.dart (+13 more)

### Community 52 - "Community 52"
Cohesion: 0.09
Nodes (22): ../../../../core/utils/commercial_pdf_generator.dart, ../../data/commercial_document_service.dart, CommercialDocType, _archiveOrUnarchive, build, _buildFilterChip, _convertDocument, createState (+14 more)

### Community 53 - "Community 53"
Cohesion: 0.09
Nodes (21): customer_state.dart, ../../data/repositories/customer_repository.dart, ../../domain/entities/customer.dart, ../../domain/entities/debt_record.dart, addCreditToCustomer, CustomerRepository, deleteCustomer, getAllCustomers (+13 more)

### Community 54 - "Community 54"
Cohesion: 0.09
Nodes (22): ../../documents/data/commercial_document_service.dart, BackupService, BackupSnapshotInfo, createdAt, createFullBackupZip, customersCount, deleteBackup, documentsCount (+14 more)

### Community 55 - "Community 55"
Cohesion: 0.10
Nodes (21): @HiveType, ProductModelAdapter, hashCode, operator, read, ShopModelAdapter, typeId, write (+13 more)

### Community 56 - "Community 56"
Cohesion: 0.10
Nodes (21): ../../../../core/data/local_sync_client.dart, ActivationPage, _ActivationPageState, _cityController, createState, dispose, _douchetteController, _douchetteFocusNode (+13 more)

### Community 57 - "Community 57"
Cohesion: 0.09
Nodes (21): activate, _computeSignature, _deviceIdKey, generateDouchetteActivationData, getDeviceId, getLicensePlan, getLicenseTypeLabel, getRemainingDays (+13 more)

### Community 58 - "Community 58"
Cohesion: 0.11
Nodes (19): core/data/local_sync_server.dart, ../../../../core/utils/staff_permissions_service.dart, AdvancedPosSettingsPage, _AdvancedPosSettingsPageState, _buildSectionHeader, createState, _customerDisplay, _editScalePrefixesDialog (+11 more)

### Community 59 - "Community 59"
Cohesion: 0.10
Nodes (19): ../../../../core/data/master_catalog_seed.dart, build, _clearSelection, createState, _displayLimit, dispose, _exportCatalog, initState (+11 more)

### Community 60 - "Community 60"
Cohesion: 0.11
Nodes (19): ../../../../core/utils/adaptive_modal_helper.dart, ../../../core/utils/online_license_service.dart, _activateOnline, ActivationModal, _ActivationModalState, build, _cityController, createState (+11 more)

### Community 61 - "Community 61"
Cohesion: 0.11
Nodes (19): ../../../../core/utils/product_image_search_service.dart, barcode, build, _buildImagePreview, createState, _currentImageUrl, didUpdateWidget, initialImageUrl (+11 more)

### Community 62 - "Community 62"
Cohesion: 0.13
Nodes (20): build, build, build, build, _buildHardwareSection, _buildSecurityAndBackupSection, _showBackupRestoreSheet, _showFinanceHubSheet (+12 more)

### Community 63 - "Community 63"
Cohesion: 0.10
Nodes (19): build, _buildKioskCard, _buildStationCard, currentSales, id, invoicesCount, ip, KioskInfo (+11 more)

### Community 64 - "Community 64"
Cohesion: 0.11
Nodes (18): ../../../backup/data/backup_service.dart, ../../../../core/utils/telegram_service.dart, ../../data/shift_service.dart, ../../data/staff_service.dart, CashierShift, _activeShift, _buildShiftStat, createState (+10 more)

### Community 65 - "Community 65"
Cohesion: 0.11
Nodes (18): allDomains, CategoryDomain, CategorySub, CategoryTaxonomy, domainId, domains, findDomain, getIconForCategory (+10 more)

### Community 66 - "Community 66"
Cohesion: 0.11
Nodes (18): create_edit_document_page.dart, ../../data/document_pdf_generator.dart, ../../data/document_service.dart, _allDocuments, _buildConvertTile, _buildDocumentCard, _buildStatBadge, _confirmDelete (+10 more)

### Community 67 - "Community 67"
Cohesion: 0.12
Nodes (18): AddCustomItemEvent, _addQuickItem, _amountStr, build, _buildNumpadRow, _categories, createState, _defaultCategories (+10 more)

### Community 68 - "Community 68"
Cohesion: 0.12
Nodes (16): copyWith, defaultItems, fromMap, icon, id, name, price, props (+8 more)

### Community 69 - "Community 69"
Cohesion: 0.12
Nodes (16): ExcelExportHelper, exportDebtsToCsv, exportInventoryAuditToCsv, exportProductsToCsv, exportSalesLogToCsv, _getOfficialHeader, formatAlgerianPhone, generateReceiptMessage (+8 more)

### Community 70 - "Community 70"
Cohesion: 0.12
Nodes (17): ../../../../core/utils/excel_export_helper.dart, _buildFilterChip, _confirmApplyReconciliation, _countedStock, createState, dispose, _incrementCount, _initAuditData (+9 more)

### Community 71 - "Community 71"
Cohesion: 0.11
Nodes (17): downloadAndSaveImageLocally, _httpClient, instance, pickAndSaveImage, ProductImageSearchResult, ProductImageSearchService, _searchBingImages, searchImages (+9 more)

### Community 72 - "Community 72"
Cohesion: 0.11
Nodes (17): _algerianUnitDictionary, _calculateSimilarity, date, discount, entityName, _fuzzyMatchWithCatalog, items, _levenshtein (+9 more)

### Community 73 - "Community 73"
Cohesion: 0.11
Nodes (17): ../../../customer/domain/entities/customer.dart, ../../../customer/presentation/cubit/customer_cubit.dart, ../../../customer/presentation/cubit/customer_state.dart, _acompteController, _buildCashChip, _buildDataCell, _buildHeaderCell, _buildPaymentModeChip (+9 more)

### Community 74 - "Community 74"
Cohesion: 0.12
Nodes (15): CatalogCrowdsourceHelper, _kEn, silentHarvest, checkForUpdates, _hasChecked, _isRemoteNewer, _showUpdateDialog, UpdateChecker (+7 more)

### Community 75 - "Community 75"
Cohesion: 0.12
Nodes (16): PrinterRole, build, createState, _fetchPrinters, initState, _isLoading, isSelectionOnly, _printers (+8 more)

### Community 76 - "Community 76"
Cohesion: 0.12
Nodes (15): getLiveAlerts, getLowStockThreshold, id, isNotificationsEnabled, _lowStockThresholdKey, message, _notifEnabledKey, NotificationService (+7 more)

### Community 77 - "Community 77"
Cohesion: 0.18
Nodes (14): UseCase, ../entities/product.dart, AddProductUseCase, AdjustStockParams, AdjustStockUseCase, call, DeleteProductUseCase, GetProductByBarcodeUseCase (+6 more)

### Community 78 - "Community 78"
Cohesion: 0.13
Nodes (14): action, amount, AuditLogEntry, AuditLogService, _boxKey, details, fromMap, getRecentLogs (+6 more)

### Community 79 - "Community 79"
Cohesion: 0.13
Nodes (14): BarcodeNormalizer, clean, findProduct, findScaleProduct, isWeightBased, itemCode, matches, normalizeAzertyInput (+6 more)

### Community 80 - "Community 80"
Cohesion: 0.13
Nodes (14): borderRadius, build, elevation, icon, isFullWidth, isLoading, label, onPressed (+6 more)

### Community 81 - "Community 81"
Cohesion: 0.14
Nodes (14): build, _countdownTimer, createState, dispose, _formatTime, initState, PcDouchetteActivationModal, _PcDouchetteActivationModalState (+6 more)

### Community 82 - "Community 82"
Cohesion: 0.13
Nodes (14): amount, date, fromMap, id, isSettled, linkedExpenseId, linkedInvoiceId, monthStr (+6 more)

### Community 83 - "Community 83"
Cohesion: 0.14
Nodes (13): bool get, cart_item.dart, fromMap, id, isExpired, itemCount, items, label (+5 more)

### Community 84 - "Community 84"
Cohesion: 0.14
Nodes (13): _buildCell, _buildHeaderCell, _buildSummaryRow, CommercialPdfGenerator, exportToDesktop, exportToMobileStorage, generatePdfData, printDocument (+5 more)

### Community 85 - "Community 85"
Cohesion: 0.14
Nodes (13): daysRemaining, expiryDate, ExpiryProductInfo, ExpiryStatus, ExpiryTrackerService, getExpiringProducts, parseDate, product (+5 more)

### Community 86 - "Community 86"
Cohesion: 0.14
Nodes (13): checkAndActivateOnline, defaultScriptUrl, isSuccess, maxDevices, message, notifyDeveloperTelegram, OnlineActivationResult, OnlineLicenseService (+5 more)

### Community 87 - "Community 87"
Cohesion: 0.14
Nodes (13): embeddedPrice, isScaleBarcode, itemCode, parse, productCode, productCodeAlt, rawBarcode, ScaleBarcodeParser (+5 more)

### Community 88 - "Community 88"
Cohesion: 0.14
Nodes (13): amount, customerId, DebtRecord, DebtTransactionType, fromMap, id, invoiceId, note (+5 more)

### Community 89 - "Community 89"
Cohesion: 0.14
Nodes (13): archiveDocument, _box, _boxName, CommercialDocumentService, convertDocument, deleteDocument, generateNextDocNumber, getDocuments (+5 more)

### Community 90 - "Community 90"
Cohesion: 0.29
Nodes (13): PrinterBloc, ConnectPrinterEvent, DisconnectPrinterEvent, InitPrinterEvent, mac, name, PrinterEvent, props (+5 more)

### Community 91 - "Community 91"
Cohesion: 0.15
Nodes (12): ../../../../core/utils/printer_helper.dart, PrinterHelper, ../../domain/repositories/printer_repository.dart, clearPrinterData, connect, disconnect, getSavedPrinterMac, getSavedPrinterName (+4 more)

### Community 92 - "Community 92"
Cohesion: 0.17
Nodes (12): ../../../core/utils/security_pin_helper.dart, build, _categories, createState, _expenses, ExpensesPage, _ExpensesPageState, initState (+4 more)

### Community 93 - "Community 93"
Cohesion: 0.15
Nodes (12): autoDiscoverChatId, defaultBotUsername, getBotToken, getChatId, getWhatsAppPhone, launchBotChat, saveSettings, sendTextMessage (+4 more)

### Community 94 - "Community 94"
Cohesion: 0.15
Nodes (12): DateTime?, AttendanceRecord, checkInTime, checkOutTime, dateStr, fromMap, id, notes (+4 more)

### Community 95 - "Community 95"
Cohesion: 0.17
Nodes (12): build, controller, _corner, createState, dispose, _isScanned, _onDetect, ScannerPage (+4 more)

### Community 96 - "Community 96"
Cohesion: 0.15
Nodes (12): address, copyWith, createdAt, currentDebt, fromMap, id, maxDebtLimit, name (+4 more)

### Community 97 - "Community 97"
Cohesion: 0.17
Nodes (12): build, createState, initState, _invoices, _loadInvoices, _showSettleDebtDialog, SupplierInvoicesPage, _SupplierInvoicesPageState (+4 more)

### Community 98 - "Community 98"
Cohesion: 0.15
Nodes (12): deleteStaff, findByBarcode, findByPin, generateUniquePin, getActiveCashiers, getActiveStaff, getAllStaff, isPinUnique (+4 more)

### Community 99 - "Community 99"
Cohesion: 0.18
Nodes (11): ../bloc/product_bloc.dart, ../../../../core/utils/expiry_tracker_service.dart, build, _buildStatBadge, createState, ExpiryMonitorPage, _ExpiryMonitorPageState, _filterStatus (+3 more)

### Community 100 - "Community 100"
Cohesion: 0.17
Nodes (11): connecting,
  connected,
  connectionFailure,
  disconnected,, connectedMac, connectedName, copyWith, devices, errorMessage, PrinterStatus, props (+3 more)

### Community 101 - "Community 101"
Cohesion: 0.18
Nodes (11): core/theme/app_theme.dart, _activeShift, build, CashierShiftsPage, _CashierShiftsPageState, _closeShiftDialog, createState, initState (+3 more)

### Community 102 - "Community 102"
Cohesion: 0.18
Nodes (11): ToggleReturnModeEvent, build, _convertToSale, createState, _devisList, DevisPage, _DevisPageState, initState (+3 more)

### Community 103 - "Community 103"
Cohesion: 0.17
Nodes (11): ../../domain/entities/commercial_document.dart, _box, boxName, convertDocument, deleteDocument, DocumentService, generateNextReference, getAllDocuments (+3 more)

### Community 104 - "Community 104"
Cohesion: 0.17
Nodes (11): PrinterRepositoryImpl, clearPrinterData, connect, disconnect, getSavedPrinterMac, getSavedPrinterName, PrinterRepository, savePrinterData (+3 more)

### Community 105 - "Community 105"
Cohesion: 0.18
Nodes (10): AppTheme, backgroundColor, errorColor, primaryColor, secondaryColor, surfaceColor, textTheme, package:google_fonts/google_fonts.dart (+2 more)

### Community 106 - "Community 106"
Cohesion: 0.18
Nodes (10): AppConstants, appLogoPath, appName, currencySymbol, defaultAddressLine1, defaultAddressLine2, defaultFooterText, defaultPhoneNumber (+2 more)

### Community 107 - "Community 107"
Cohesion: 0.20
Nodes (10): build, createState, initState, _items, _loadItems, _printList, _removeItem, ShoppingListPage (+2 more)

### Community 108 - "Community 108"
Cohesion: 0.18
Nodes (10): addRecord, calculateMonthlySettlement, formatThermalPaySlip, getStaffRecords, getUnsettledRecords, PayrollService, settleMonthlySalary, package:uuid/uuid.dart (+2 more)

### Community 109 - "Community 109"
Cohesion: 0.20
Nodes (9): ../../../../core/utils/barcode_normalizer.dart, ../../domain/repositories/product_repository.dart, addProduct, adjustStock, deleteProduct, getProductByBarcode, getProducts, updateProduct (+1 more)

### Community 110 - "Community 110"
Cohesion: 0.20
Nodes (9): ../../../core/utils/whatsapp_helper.dart, dart:typed_data, _buildPdfTotalRow, DocumentPdfGenerator, generateA4Document, printDocument, sendViaWhatsApp, package:pdf/pdf.dart (+1 more)

### Community 111 - "Community 111"
Cohesion: 0.20
Nodes (9): ../../domain/entities/product.dart, ProductRepositoryImpl, addProduct, adjustStock, deleteProduct, getProductByBarcode, getProducts, ProductRepository (+1 more)

### Community 112 - "Community 112"
Cohesion: 0.24
Nodes (10): build, build, _showPartnersHubSheet, Route /customers, Route /devis, Route /products/add, Route /products/catalog, Route /products/inventory-audit (+2 more)

### Community 113 - "Community 113"
Cohesion: 0.20
Nodes (10): DesktopPosPage, HomePage, SmartScaleModal, AddProductPage, EditProductPage, NewSupplierInvoicePage, ShelfLabelsPage, StockInPage (+2 more)

### Community 114 - "Community 114"
Cohesion: 0.20
Nodes (9): _onConnect, _onDisconnect, _onInit, _onRefresh, _onScan, _onTestPrint, repository, printer_event.dart (+1 more)

### Community 115 - "Community 115"
Cohesion: 0.22
Nodes (9): build, build, _buildScannerSection, _showInventoryHubSheet, Route /master-catalog, Route /products/expiry-monitor, Route /products/losses, Route /products/shopping-list (+1 more)

### Community 116 - "Community 116"
Cohesion: 0.22
Nodes (8): addressLine1, addressLine2, copyWith, footerText, name, phoneNumber, props, upiId

### Community 117 - "Community 117"
Cohesion: 0.25
Nodes (7): double get, copyWith, product, props, quantity, total, ../../../product/domain/entities/product.dart

### Community 118 - "Community 118"
Cohesion: 0.29
Nodes (6): attendance_record_model.dart, core/data/hive_database.dart, AttendanceService, countDaysWorked, getMonthlyAttendance, recordPointage

### Community 119 - "Community 119"
Cohesion: 0.38
Nodes (6): ../bloc/billing_bloc.dart, DeleteHeldCartEvent, ResumeHeldCartEvent, ../../domain/entities/held_cart.dart, build, HeldCartsModal

### Community 120 - "Community 120"
Cohesion: 0.29
Nodes (7): QuickItem, BillingState, ProductState, Equatable, CartItem, HeldCart, PrinterState

### Community 121 - "Community 121"
Cohesion: 0.29
Nodes (6): BarcodeGeneratorHelper, calculateEan13Checksum, generateNextShortSku, generateUniqueInStoreEan13, dart:math, ../data/hive_database.dart

### Community 122 - "Community 122"
Cohesion: 0.29
Nodes (7): InputLabel, PrimaryButton, PosHeaderToolbar, _BarcodeStripeWidget, DevicePairingModal, LivePosRadarWidget, StatelessWidget

### Community 123 - "Community 123"
Cohesion: 0.29
Nodes (7): _handleSecretTap, _activateOnline, _handleDouchetteActivation, _processMasterPairing, build, Route /, Route /activation

### Community 124 - "Community 124"
Cohesion: 0.40
Nodes (5): _handleLowStockBadgeTap, build, build, build, Route /products

### Community 126 - "Community 126"
Cohesion: 0.67
Nodes (3): _navigateToSettings, build, Route /settings

### Community 127 - "Community 127"
Cohesion: 0.67
Nodes (3): KioskPriceCheckerPage, _KioskPriceCheckerPageState, TickerProviderStateMixin

### Community 128 - "Community 128"
Cohesion: 0.67
Nodes (3): DocumentsHubPage, _DocumentsHubPageState, SingleTickerProviderStateMixin

## Knowledge Gaps
- **2034 isolated node(s):** `router`, `HiveDatabase`, `productBoxName`, `shopBoxName`, `settingsBoxName` (+2029 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 2208 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **3 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `ProductBloc` connect `Community 28` to `Community 1`, `Community 2`, `Community 4`, `Community 5`, `Community 7`, `Community 13`, `Community 14`, `Community 26`, `Community 29`, `Community 30`, `Community 39`, `Community 40`, `Community 41`, `Community 42`, `Community 45`, `Community 46`, `Community 51`, `Community 56`, `Community 59`, `Community 67`, `Community 70`, `Community 99`, `Community 112`, `Community 120`, `Community 123`?**
  _High betweenness centrality (0.028) - this node is a cross-community bridge._
- **Why does `BillingBloc` connect `Community 7` to `Community 2`, `Community 67`, `Community 3`, `Community 5`, `Community 102`, `Community 4`, `Community 73`, `Community 42`, `Community 46`, `Community 47`, `Community 119`, `Community 120`, `Community 28`?**
  _High betweenness centrality (0.014) - this node is a cross-community bridge._
- **Why does `Product` connect `Community 55` to `Community 3`, `Community 38`, `Community 41`, `Community 13`, `Community 47`, `Community 117`, `Community 85`, `Community 120`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **What connects `router`, `HiveDatabase`, `productBoxName` to the rest of the system?**
  _2034 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.029850746268656716 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.030303030303030304 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.031746031746031744 - nodes in this community are weakly interconnected._