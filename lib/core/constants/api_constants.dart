class ApiConstants {
  static const String baseUrl = 'https://api.dev.driverpos.io/api/v1';

  // Dynamic page-config backend (Redis-backed, no auth required)
  static const String pageConfigBaseUrl = 'https://driverpos-backend-app.onrender.com';
  static const String pageConfigPath = '/api/v1/page';

  // Auth
  static const String login = '/auth/login';
  static const String refreshToken = '/auth/accesstoken';
  static const String updatePassword = '/auth/password';
  static const String forgotPassword = '/auth/password/forgot';
  static const String resetPassword = '/auth/password/reset';

  // Time Clock
  static const String clockIn = '/timeClock/clock-in';
  static const String clockOut = '/timeClock/clock-out';
  static const String verifyPin = '/employee/verify-pin';

  // Cash Register
  static const String addCashRegister = '/cashRegister/add';
  static const String closeCashRegister = '/cashRegister/close';
  static const String checkCashRegister = '/cashRegister/check';

  // Tee Sheet
  static const String teeSheet = '/teesheet';
  static const String bookSlot = '/teesheet/book';
  static const String slotDetails = '/teesheet/book';    // GET /teesheet/book/:slotId
  static const String updateBooking = '/teesheet/book/update';
  static const String deleteBooking = '/teesheet/book/delete';
  static const String teeSheetCustomers = '/teeSheet/customers';
  static const String teeSheetNoShow = '/teesheet/book/noshow';
  static const String teeSheetPending = '/teesheet/pending';
  static const String getAllTeesheets = '/teesheet/all';
  static const String teeSheetBlock = '/teesheetBlock';
  static const String teeSheetBlockUpdate = '/teesheetBlock/update';
  static const String teeSheetBlockDelete = '/teesheetBlock/delete';

  // Customers
  static const String customerList = '/customer';
  static const String createCustomer = '/customer/add';
  static const String customerSuggestion = '/customer/suggestion';
  static const String updateCustomer = '/customer/update';
  static const String deleteCustomer = '/customer/delete';
  static const String customerSearch = '/customer/search';
  static const String addStoreCredit = '/storecredit/add';
  static const String customerStoreCredit = '/storecredit/customer';

  // Employees
  static const String employeeList = '/employee';
  static const String createEmployee = '/employee/add';
  static const String updateEmployee = '/employee/update';
  static const String deleteEmployee = '/employee/delete';
  static const String employeeSearch = '/employee/search';

  // Inventory
  static const String inventoryList = '/inventory';
  static const String addInventory = '/inventory/add';
  static const String updateInventory = '/inventory/update';
  static const String deleteInventory = '/inventory/delete';
  static const String inventorySearch = '/inventory/search';
  static const String inventoryCategory = '/category/inventoryCategory';

  // Products / Labels
  static const String labels = '/label';
  static const String labelProducts = '/label/products';
  static const String createLabel = '/label/add';
  static const String addProductToLabel = '/label/products/add';
  static const String updateLabel = '/label/update';
  static const String deleteLabel = '/label/delete';
  static const String barcodeScan = '/label/products/scan';

  // Departments
  static const String departments = '/department';
  static const String createDepartment = '/department/add';
  static const String updateDepartment = '/department/update';
  static const String deleteDepartment = '/department/delete';

  // Sales / POS
  static const String addCustomerToSales = '/sales/add/customer';
  static const String salesDetails = '/sales';
  static const String addProductsToSales = '/sales/add/product';
  static const String addItemToSales = '/sales/add/item';
  static const String clearSales = '/sales/clear';
  static const String removeFromSales = '/sales/remove';
  static const String holdSales = '/sales/cart';
  static const String holdCarts = '/sales/holdcarts';
  static const String cartConfig = '/sales/cart-config';

  // Payment / Transaction
  static const String payWithGiftCard = '/transaction/applyGiftCard';
  static const String checkout = '/transaction/checkout';
  static const String transactionRefund = '/transaction/refund';
  static const String issueRefund = '/transaction/issue-refund';
  static const String sendOtp = '/transaction/sendOtp';
  static const String transactionEmailReceipt = '/report/transaction/email';
  static const String transactionSearch = 'report/transaction/search';
  static const String transactionAmount = 'report/transaction/data';
  static const String voidTransaction = '/transaction/void';

  // Gift Cards
  static const String giftCards = '/giftCard';
  static const String addGiftCard = '/giftCard/add';
  static const String updateGiftCard = '/giftCard/update';
  static const String searchGiftCard = '/giftCard/search';

  // Terminals
  static const String terminals = '/terminal';
  static const String onlineTerminals = '/terminal/online';
  static const String terminalStatus = '/terminal/status';

  // Membership
  static const String memberships = '/membership';
  static const String createMembership = '/membership/add';
  static const String updateMembership = '/membership/update';

  // Reports
  static const String reports = '/report';
  static const String departmentReport = '/report/department';
  static const String transactionReport = '/report/transaction';
  static const String zOutReport = '/report/z-out';
  static const String employeeTimeClock = '/report/timeclock/breakdown';
  static const String overallTimeClock = '/report/timeclock/overall';
  static const String registerLog = '/report/cash-register';
  static const String lowInventoryReport = 'report/inventory/lowstock';
  static const String customerReport = '/report/customer';
  static const String salesReport = '/report/accounting/payments';
  static const String tipReport = '/report/transactions/tips';
  static const String teeSheetReport = '/report/tee-sheet/tee-times';
  static const String departmentSummaryReport = 'report/department/summary';

  // Dashboard
  static const String dashboardConfig = '/dashboard/config';

  // Work Stations
  static const String workstations = '/workstation';
  static const String createWorkstation = '/workstation/add';
  static const String updateWorkstation = '/workstation/update';
  static const String deleteWorkstation = '/workstation/delete';

  // Golf Course
  static const String golfCourses = '/golfCourse';

  // Permission Tree
  static const String permissionTree = '/permission-tree/workstation';

  // Settings
  static const String pageSettings = '/pageSettings';
  static const String customerPageSettings = '/pageSettings/customerPageSettings';
  static const String employeePageSettings = '/pageSettings/employeePageSettings';
  static const String inventoryPageSettings = '/pageSettings/inventoryPageSettings';
}
