use kajjabase;
DELIMITER//

CREATE PROCEDURE pRegisterCustomer(IN parName VARCHAR(255), IN parEmail VARCHAR(255), IN parPass VARCHAR(255), IN parPhone VARCHAR(20))
BEGIN
    DECLARE v_NewID VARCHAR(10);
    DECLARE v_Prefix VARCHAR(3);
    DECLARE v_Count INT;
    DECLARE v_Suffix VARCHAR(2);
    SET v_Prefix = UPPER(SUBSTRING(parName, 1, 3));
    SELECT COUNT(*) INTO v_Count FROM Customers WHERE Customer_ID LIKE CONCAT(v_Prefix, '%');
    SET v_Suffix = LPAD(v_Count + 1, 2, '0');
    SET v_NewID = CONCAT(v_Prefix, v_Suffix);
    INSERT INTO Customers (Customer_ID, Customer_Name, Cust_Email, Cust_Password, Cust_Number, status_del) VALUES (v_NewID, parName, parEmail, md5(parPass), parPhone, 0);
    SELECT CONCAT('Registration Successful ID: ', v_NewID) AS Message;
END //

CREATE PROCEDURE pUpdateProfile(IN parCustID VARCHAR(10), IN parNewEmail VARCHAR(255), IN parNewPhone VARCHAR(20))
BEGIN
    UPDATE Customers
    SET Cust_Email =
        CASE
                         WHEN parNewEmail IS NULL OR parNewEmail = '' THEN Cust_Email
                         ELSE parNewEmail
        END,
        Cust_Number =
        CASE
                          WHEN parNewPhone IS NULL OR parNewPhone = '' THEN Cust_Number
                          ELSE parNewPhone
        END
    WHERE Customer_ID = parCustID;

    SELECT 'Profile Updated Successfully' AS Message;
END //

CREATE PROCEDURE pGetCustomerHistory(IN parCustID VARCHAR(10))
BEGIN
    SELECT s.Sales_ID, s.Date_Completed, p.Product_Name, sl.Quantity, sl.Total_Price FROM Sales s JOIN Sales_List sl ON s.Sales_ID = sl.Sales_ID JOIN Products p ON sl.Product_ID = p.Product_ID JOIN Orders o ON s.Orders_ID = o.Orders_ID WHERE o.Customer_ID = parCustID ORDER BY s.Date_Completed DESC;
END //

CREATE PROCEDURE pAddNewProduct(IN parName VARCHAR(50), IN parPrice  FLOAT(12, 2))
BEGIN
    DECLARE v_NewID VARCHAR(10);
    DECLARE v_Count INT;
    SELECT COUNT(*) INTO v_Count FROM Products;
    SET v_NewID = CONCAT('P', LPAD(v_Count + 1, 4, '0'));
    INSERT INTO Products (Product_ID, Product_Name, Sell_Price, status_del) VALUES (v_NewID, parName, parPrice, 0);
    SELECT CONCAT('Product Added: ', v_NewID) AS Message;
END //

CREATE PROCEDURE pRecordProduction(IN parProdID VARCHAR(10), IN parQty INT, IN parCost  FLOAT(12, 2))
BEGIN
    DECLARE v_NewID VARCHAR(10);
    DECLARE v_DateCode VARCHAR(6);
    DECLARE v_Count INT;
    SET v_DateCode = DATE_FORMAT(CURDATE(), '%d%m%y');
    SELECT COUNT(*) INTO v_Count FROM Production WHERE Date_In = CURDATE();
    SET v_NewID = CONCAT('PR', v_DateCode, LPAD(v_Count + 1, 2, '0'));
    INSERT INTO Production (Production_ID, Product_ID, Date_In, Quantity, Production_Cost, status_del) VALUES (v_NewID, parProdID, CURDATE(), parQty, parCost, 0);
    SELECT CONCAT('Production Recorded: ', v_NewID) AS Message;
END //

CREATE PROCEDURE pRecordWaste(IN parProductionID VARCHAR(10), IN parQty INT)
BEGIN
    DECLARE v_NewID VARCHAR(10);
    DECLARE v_DateCode VARCHAR(6);
    DECLARE v_Count INT;
    SET v_DateCode = DATE_FORMAT(CURDATE(), '%d%m%y');
    SELECT COUNT(*) INTO v_Count FROM Waste;
    SET v_NewID = CONCAT('W', v_DateCode, LPAD(v_Count + 1, 2, '0'));
    INSERT INTO Waste (Waste_ID, Production_ID, Quantity, status_del) VALUES (v_NewID, parProductionID, parQty, 0);
    SELECT CONCAT('Waste Recorded: ', v_NewID) AS Message;
END //

CREATE PROCEDURE pCreateOrder(IN parCustID VARCHAR(10))
BEGIN
    DECLARE v_NewID VARCHAR(10);
    DECLARE v_DateCode VARCHAR(6);
    DECLARE v_Count INT;
    DECLARE v_ActiveBatchID VARCHAR(10);

    SELECT Batch_ID INTO v_ActiveBatchID FROM Batches WHERE Status = 1 LIMIT 1;

    IF v_ActiveBatchID IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Pre-Order is CLOSED. Cannot place order now.';
    ELSE
        SET v_DateCode = DATE_FORMAT(CURDATE(), '%d%m%y');
        SELECT COUNT(*) INTO v_Count FROM Orders WHERE Order_For_Date = CURDATE();
        SET v_NewID = CONCAT('O', v_DateCode, LPAD(v_Count + 1, 2, '0'));

        INSERT INTO Orders (Orders_ID, Customer_ID, Batch_ID, Date_In, Order_Status, Order_For_Date, status_del)
        VALUES (v_NewID, parCustID, v_ActiveBatchID, CURDATE(), 0, CURDATE(), 0);

        SELECT CONCAT('Order Placed in ', v_ActiveBatchID) AS Message;
    END IF;
END //

CREATE PROCEDURE pAddItemToOrder(IN parOrderID VARCHAR(10), IN parProdID VARCHAR(10), IN parQty INT)
BEGIN
    DECLARE v_Status INT;
    SELECT Order_Status INTO v_Status FROM Orders WHERE Orders_ID = parOrderID;
    IF v_Status = 0 THEN
        INSERT INTO Order_List (Product_ID, Orders_ID, Quantity, Order_Date) VALUES (parProdID, parOrderID, parQty, CURDATE());
        SELECT 'Item Added' AS Message;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot modify processed orders';
    END IF;
END //

CREATE PROCEDURE pRemoveItemFromOrder(IN parOrderID VARCHAR(10), IN parProdID VARCHAR(10))
BEGIN
    DECLARE v_Status INT;
    SELECT Order_Status INTO v_Status FROM Orders WHERE Orders_ID = parOrderID;
    IF v_Status = 0 THEN
        DELETE FROM Order_List WHERE Orders_ID = parOrderID AND Product_ID = parProdID;
        SELECT 'Item Removed' AS Message;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot modify processed orders';
    END IF;
END //

CREATE PROCEDURE pUpdateStatus(IN parOrderID VARCHAR(10), IN parNewStatus INT)
BEGIN
    UPDATE Orders SET Order_Status = parNewStatus WHERE Orders_ID = parOrderID;
    SELECT 'Status Updated' AS Message;
END //


CREATE PROCEDURE pCheckoutTrans(IN parOrderID VARCHAR(10), IN parPayment VARCHAR(15))
BEGIN
    DECLARE v_SalesID VARCHAR(10);
    DECLARE v_DateCode VARCHAR(6);
    DECLARE v_Count INT;
    DECLARE v_Suffix VARCHAR(2);
    SET v_DateCode = DATE_FORMAT(CURDATE(), '%d%m%y');
    SELECT COUNT(*) INTO v_Count FROM Sales WHERE Date_Completed = CURDATE();
    SET v_Suffix = LPAD(v_Count + 1, 2, '0');
    SET v_SalesID = CONCAT('S', v_DateCode, v_Suffix);
    INSERT INTO Sales (Sales_ID, Orders_ID, Date_Completed, Payment, status_del) VALUES (v_SalesID, parOrderID, CURDATE(), parPayment, 0);
    INSERT INTO Sales_List (Product_ID, Sales_ID, Quantity, Total_Price) SELECT ol.Product_ID, v_SalesID, ol.Quantity, (ol.Quantity * p.Sell_Price) FROM Order_List ol JOIN Products p ON ol.Product_ID = p.Product_ID WHERE ol.Orders_ID = parOrderID;
    SELECT 'Successfully added to Sales' AS Message;
END //

CREATE PROCEDURE pSubmitReview(IN parCustID VARCHAR(10), IN parSalesID VARCHAR(10), IN parRating INT, IN parComment TEXT)
BEGIN
    DECLARE v_Check INT;
    DECLARE v_FeedbackID VARCHAR(10);
    DECLARE v_CustInitials VARCHAR(3);
    DECLARE v_Count INT;
    DECLARE v_Suffix VARCHAR(2);
    SELECT COUNT(*) INTO v_Check FROM Sales WHERE Sales_ID = parSalesID;
    IF v_Check > 0 THEN
        SELECT UPPER(SUBSTRING(Customer_Name, 1, 3)) INTO v_CustInitials FROM Customers WHERE Customer_ID = parCustID;
        SELECT COUNT(*) INTO v_Count FROM Feedback WHERE Feedback_ID LIKE CONCAT('F', v_CustInitials, '%');
        SET v_Suffix = LPAD(v_Count + 1, 2, '0');
        SET v_FeedbackID = CONCAT('F', v_CustInitials, v_Suffix);
        INSERT INTO Feedback (Feedback_ID, Sales_ID, Customer_ID, Feedback_comment, Rating, status_del) VALUES (v_FeedbackID, parSalesID, parCustID, parComment, parRating, 0);
        SELECT 'Successfully submitted to Feedback' AS Message;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sales ID not found';
    END IF;
END //

CREATE PROCEDURE pOrderGenID(IN parDate DATE, OUT parID VARCHAR(15))
BEGIN
    DECLARE v_DateCode VARCHAR(6);
    DECLARE v_Count INT;
    DECLARE v_Suffix VARCHAR(2);
    SET v_DateCode = DATE_FORMAT(parDate, '%d%m%y');
    SELECT COUNT(*) INTO v_Count FROM Orders WHERE Order_For_Date = parDate;
    SET v_Suffix = LPAD(v_Count + 1, 2, '0');
    SET parID = CONCAT('O', v_DateCode, v_Suffix);
END //

CREATE PROCEDURE pOpenBatch(
    IN parName VARCHAR(50),
    IN parCloseDate DATETIME,
    IN parDeliveryDate DATE
)
BEGIN
    DECLARE v_NewID VARCHAR(10);
    DECLARE v_DateCode VARCHAR(6);
    DECLARE v_Count INT;
    DECLARE v_CheckActive INT;

    SELECT COUNT(*) INTO v_CheckActive FROM Batches WHERE Status = 1;

    IF v_CheckActive > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: A Batch is already OPEN. Close it first.';
    ELSE
        SET v_DateCode = DATE_FORMAT(NOW(), '%d%m%y');
        SELECT COUNT(*) INTO v_Count FROM Batches WHERE DATE(Open_Date) = CURDATE();
        SET v_NewID = CONCAT('B', v_DateCode, LPAD(v_Count + 1, 2, '0'));

        INSERT INTO Batches (Batch_ID, Batch_Name, Open_Date, Close_Date, Delivery_Date, Status, status_del)
        VALUES (v_NewID, parName, NOW(), parCloseDate, parDeliveryDate, 1, 0);

        SELECT CONCAT('Pre-Order Started: ', v_NewID) AS Message;
    END IF;
END //

CREATE PROCEDURE pCloseBatch()
BEGIN
    DECLARE v_BatchID VARCHAR(10);

SELECT Batch_ID INTO v_BatchID FROM Batches WHERE Status = 1 LIMIT 1;

IF v_BatchID IS NOT NULL THEN
UPDATE Batches
SET Close_Date = NOW(), Status = 0
WHERE Batch_ID = v_BatchID;

SELECT CONCAT('Pre-Order Closed for: ', v_BatchID) AS Message;
ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: No Open Batch found.';
END IF;
END //

DELIMITER;