-- harus urut
use kajjabase;

-- Generate Customer ID
SELECT fGenCustID('Zahck Snyder');

-- Register a new customer
CALL pRegisterCustomer('Zahck Snyder', 'zack@mail.com', 'pass123', '0811223344');
SELECT * FROM customers;

-- Update Profile (NULL = Same)
CALL pUpdateProfile('ZAH01', 'realzack@mail.com', '0811223344');
CALL pUpdateProfile('BUD01', NULL, '08999999999');
SELECT * FROM customers;

-- Add New Product
CALL pAddNewProduct('Spicy BapBap (SUPER)', 40000);
SELECT * FROM products;

-- Record Production
CALL pRecordProduction('P0005', 30, 15000);
SELECT * FROM production;

-- Record Waste
CALL pRecordWaste(CONCAT('PR', DATE_FORMAT(CURDATE(), '%d%m%y'),'01'),5);
SELECT * FROM waste;

-- Generate ID for Order
SET @futureID = null;
CALL pOrderGenID('2026-01-01', @futureID);
SELECT @futureID;

-- Open Active Batch
CALL pOpenBatch('Batch December', '2025-12-1 23:59:00', '2025-12-20');
SELECT * FROM batches;

-- Create New Order
CALL pCreateOrder('ZAH01');
SELECT * FROM orders;

-- Close Active Batch
CALL pCloseBatch();
SELECT * FROM batches;

-- Add Items
CALL pAddItemToOrder(CONCAT('O', DATE_FORMAT(CURDATE(), '%d%m%y'),'01'), 'P0005', 2);
CALL pAddItemToOrder(CONCAT('O', DATE_FORMAT(CURDATE(), '%d%m%y'),'01'), 'P0001', 1);
SELECT * FROM order_list WHERE Orders_ID = CONCAT('O', DATE_FORMAT(CURDATE(), '%d%m%y'),'01');

-- Remove Item
CALL pRemoveItemFromOrder(CONCAT('O', DATE_FORMAT(CURDATE(), '%d%m%y'),'01'), 'P0001');
SELECT * FROM order_list WHERE Orders_ID = CONCAT('O', DATE_FORMAT(CURDATE(), '%d%m%y'),'01');

-- Check Cart Total
SELECT fEstCartTotal(CONCAT('O', DATE_FORMAT(CURDATE(), '%d%m%y'),'01'));

-- Pending Orders (Order_Status = 0)
SELECT * FROM vPendingOrder;

-- Manual Status Update (1 = to Deliver)
CALL pUpdateStatus(CONCAT('O', DATE_FORMAT(CURDATE(), '%d%m%y'),'01'), 1);
SELECT * FROM Orders WHERE Orders_ID = CONCAT('O', DATE_FORMAT(CURDATE(), '%d%m%y'),'01');

-- Pay for Order
CALL pCheckoutTrans(CONCAT('O', DATE_FORMAT(CURDATE(), '%d%m%y'),'01'), 'Transfer');
SELECT * FROM Orders WHERE Orders_ID = CONCAT('O', DATE_FORMAT(CURDATE(), '%d%m%y'),'01');
SELECT * FROM Sales;

-- Check Stock
SELECT fLiveStock('P0005');

-- Submit Review
CALL pSubmitReview('ZAH01', CONCAT('S', DATE_FORMAT(CURDATE(), '%d%m%y'),'01'), 5, 'enaeeaeaenaeak!');
SELECT * FROM feedback;

-- Check Customer History
CALL pGetCustomerHistory('ZAH01');

-- Check Average Rating
SELECT fGetAvgRating('P0005');

-- Check Profit Margin
SELECT fGetProductMargin('P0005');

-- Check Waste Ratio (Percentage)
SELECT fGetWasteRatio('P0005');

-- Format Currency
SELECT fFormatCurrency(80000);

-- Sales Today
SELECT * FROM vSalesToday;

-- Best Customers
SELECT * FROM vBestCustomers;

-- Pending Orders (Order_Status = 0)
SELECT * FROM vPendingOrder;

-- Real Profitability (From Production Cost & Waste)
SELECT * FROM vProdProfit;

-- Low Stock Alert (< 10)
SELECT * FROM vLowStockAlert;

-- Top Selling Products
SELECT * FROM vTopSellingProducts;

-- Insufficient Stock
INSERT INTO Sales_List (Product_ID, Sales_ID, Quantity, Total_Price)
VALUES ('P0001', 'S12112501', 9999999, 0);

-- Validate Rating (1-5)
INSERT INTO Feedback (Feedback_ID, Sales_ID, Customer_ID, Feedback_comment, Rating, status_del)
VALUES ('FTEST_R', 'S12112501', 'BUD01', '1999999999/1000000', 100, 0);
SELECT * FROM Feedback WHERE Feedback_ID = 'FTEST_R';

-- Auto Close Order
INSERT INTO Orders (Orders_ID, Customer_ID, Batch_ID, Date_In, Order_Status, Order_For_Date, status_del)
VALUES ('O_TEST_CL', 'BUD01', 'B112501', CURDATE(), 0, CURDATE(), 0);
SELECT Orders_ID, Order_Status FROM Orders WHERE Orders_ID = 'O_TEST_CL';
INSERT INTO Sales (Sales_ID, Orders_ID, Date_Completed, Payment, status_del)
VALUES ('S_TEST_CL', 'O_TEST_CL', CURDATE(), 'Cash', 0);
SELECT Orders_ID, Order_Status FROM Orders WHERE Orders_ID = 'O_TEST_CL';

-- Auto Sales Price
INSERT INTO Sales_List (Product_ID, Sales_ID, Quantity, Total_Price)
VALUES ('P0002', 'S_TEST_CL', 2, 0);
SELECT Total_Price FROM Sales_List WHERE Sales_ID = 'S_TEST_CL' AND Product_ID = 'P0002';

-- Prevent Future Date
INSERT INTO Orders (Orders_ID, Customer_ID, Date_In, Order_Status, Order_For_Date, status_del)
VALUES ('O9999', 'ZAC01', '2099-01-01', 0, '2099-01-01', 0);

-- Ensure Valid Email
INSERT INTO Customers (Customer_ID, Customer_Name, Cust_Email, Cust_Password, Cust_Number, status_del)
VALUES ('BAD01', 'Fake', 'email.com', 'pass', '000', 0);

-- Prevent Delete Active Customer (Has Unfinished Orders)
CALL pCreateOrder('ZAH01');
UPDATE Customers SET status_del = 1 WHERE Customer_ID = 'ZAH01';

-- Auto Fill Waste
INSERT INTO Waste (Waste_ID, Production_ID, Product_ID, Quantity, Price, status_del)
VALUES ('W_AUTO', 'PR01112501', NULL, 5, 0, 0);
SELECT * FROM Waste WHERE Waste_ID = 'W_AUTO';