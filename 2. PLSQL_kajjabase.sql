/*==============================================================*/
/* VIEWS                                                        */
/*==============================================================*/
-- vSalesToday
CREATE OR REPLACE VIEW vSalesToday AS
    SELECT s.Sales_ID, s.Date_Completed, SUM(sl.Total_Price) as Daily_Revenue 
    FROM Sales s
    JOIN Sales_List sl ON s.Sales_ID = sl.Sales_ID
    WHERE s.Date_Completed = CURDATE()
    GROUP BY s.Sales_ID, s.Date_Completed;

-- vBestCustomers
CREATE OR REPLACE VIEW vBestCustomers AS
    SELECT c.Customer_Name, COUNT(DISTINCT s.Sales_ID) as Total_Transactions,
           SUM(sl.Total_Price) as Total_Value 
    FROM Customers c
    JOIN Orders o ON c.Customer_ID = o.Customer_ID
    JOIN Sales s ON o.Orders_ID = s.Orders_ID
    JOIN Sales_List sl ON s.Sales_ID = sl.Sales_ID
    WHERE c.status_del = 0
    GROUP BY c.Customer_ID, c.Customer_Name;

-- vPendingOrder
CREATE OR REPLACE VIEW vPendingOrder AS
SELECT o.Orders_ID, c.Customer_Name, o.Order_For_Date,
CASE 
	WHEN o.Order_Status = 0 THEN 'Process'
	WHEN o.Order_Status = 1 THEN 'Delivery'
	WHEN o.Order_Status = 2 THEN 'Done'
	ELSE 'Unknown'
END AS Order_Status
FROM Orders o
JOIN Customers c ON o.Customer_ID = c.Customer_ID
LEFT JOIN Sales s ON o.Orders_ID = s.Orders_ID
WHERE s.Sales_ID IS NULL AND o.status_del = 0;

-- vProdProfit
CREATE OR REPLACE VIEW vProdProfit AS
SELECT
    p.Product_Name,
    COALESCE(SUM(sl.Total_Price), 0) AS Total_Revenue,
    (COALESCE(SUM(sl.Quantity), 0) * (SELECT AVG(Production_Cost) FROM Production pr WHERE pr.Product_ID = p.Product_ID)) AS Total_COGS,
    (SELECT COALESCE(SUM(Price), 0) FROM Waste w WHERE w.Product_ID = p.Product_ID) AS Total_Waste_Cost,
    (   COALESCE(SUM(sl.Total_Price), 0) -
        (COALESCE(SUM(sl.Quantity), 0) * (SELECT AVG(Production_Cost) FROM Production pr WHERE pr.Product_ID = p.Product_ID)) -
        (SELECT COALESCE(SUM(Price), 0) FROM Waste w WHERE w.Product_ID = p.Product_ID)
        ) AS Net_Profit
FROM Products p
LEFT JOIN Sales_List sl ON p.Product_ID = sl.Product_ID
GROUP BY p.Product_ID, p.Product_Name;

-- vTopSellingProducts
CREATE OR REPLACE VIEW vTopSellingProducts AS
    SELECT p.Product_Name, SUM(sl.Quantity) as Units_Sold 
    FROM Products p
    JOIN Sales_List sl ON p.Product_ID = sl.Product_ID
GROUP BY p.Product_Name
ORDER BY Units_Sold DESC;

-- vLowStockAlert
CREATE OR REPLACE VIEW vLowStockAlert AS
SELECT p.Product_ID, p.Product_Name, fLiveStock(p.Product_ID) as Current_Stock
FROM Products p 
WHERE fLiveStock(p.Product_ID) < 10;


DROP FUNCTION IF EXISTS fFormatCurrency;
DROP FUNCTION IF EXISTS fGetAvgRating;
DROP FUNCTION IF EXISTS fGetProductMargin;
DROP FUNCTION IF EXISTS fGetWasteRatio;
DROP FUNCTION IF EXISTS fEstCartTotal;
DROP FUNCTION IF EXISTS fGenCustID;
DROP FUNCTION IF EXISTS fLiveStock;

DROP PROCEDURE IF EXISTS pCheckoutTrans;
DROP PROCEDURE IF EXISTS pSubmitReview;
DROP PROCEDURE IF EXISTS pOrderGenID;
DROP PROCEDURE IF EXISTS pRegisterCustomer;
DROP PROCEDURE IF EXISTS pUpdateProfile;
DROP PROCEDURE IF EXISTS pAddItemToOrder;
DROP PROCEDURE IF EXISTS pRecordProduction;
DROP PROCEDURE IF EXISTS pAddNewProduct;
DROP PROCEDURE IF EXISTS pCreateOrder;
DROP PROCEDURE IF EXISTS pRemoveItemFromOrder;
DROP PROCEDURE IF EXISTS pUpdateStatus;
DROP PROCEDURE IF EXISTS pGetCustomerHistory;
DROP PROCEDURE IF EXISTS pOpenBatch;
DROP PROCEDURE IF EXISTS pCloseBatch;

DROP TRIGGER IF EXISTS tAutoPrice;
DROP TRIGGER IF EXISTS tCloseOrder;
DROP TRIGGER IF EXISTS tStockCheck;
DROP TRIGGER IF EXISTS tCheckRating;
DROP TRIGGER IF EXISTS tAutoFillWaste;
DROP TRIGGER IF EXISTS tEnsureValidEmail;
DROP TRIGGER IF EXISTS tPreventDeleteActiveCustomer;
DROP TRIGGER IF EXISTS tPreventFutureDate;

DELIMITER //

/*==============================================================*/
/* FUNCTION                                                     */
/*==============================================================*/
-- fLiveStock
CREATE FUNCTION fLiveStock(parProdID VARCHAR(10)) 
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE v_Prod INT DEFAULT 0;
    DECLARE v_Sold INT DEFAULT 0;
    DECLARE v_Waste INT DEFAULT 0;

    SELECT COALESCE(SUM(Quantity),0) INTO v_Prod 
    FROM Production 
    WHERE Product_ID = parProdID;

    SELECT COALESCE(SUM(Quantity),0) INTO v_Sold 
    FROM Sales_List 
    WHERE Product_ID = parProdID;

    SELECT COALESCE(SUM(Quantity),0) INTO v_Waste 
    FROM Waste 
    WHERE Product_ID = parProdID;

    RETURN (v_Prod - v_Sold - v_Waste);
END //

-- fEstCartTotal
CREATE FUNCTION fEstCartTotal(parOrderID VARCHAR(10)) 
RETURNS FLOAT(12, 2)
DETERMINISTIC
BEGIN
    DECLARE v_Total  FLOAT(12, 2);

    SELECT SUM(ol.Quantity * p.Sell_Price) INTO v_Total 
    FROM Order_List ol 
    JOIN Products p ON ol.Product_ID = p.Product_ID
    WHERE ol.Orders_ID = parOrderID;

    RETURN COALESCE(v_Total, 0.00);
END //

-- fGenCustID
CREATE FUNCTION fGenCustID(parCustName VARCHAR(255)) 
RETURNS VARCHAR(10)
DETERMINISTIC
BEGIN
    DECLARE v_Prefix VARCHAR(3);
    DECLARE v_Count INT;
    DECLARE v_Suffix VARCHAR(2);
    SET v_Prefix = UPPER(SUBSTRING(parCustName, 1, 3));
    
    SELECT COUNT(*) INTO v_Count 
    FROM Customers 
    WHERE Customer_ID 
    LIKE CONCAT(v_Prefix, '%');

    SET v_Suffix = LPAD(v_Count + 1, 2, '0');
    RETURN CONCAT(v_Prefix, v_Suffix);
END //

-- fGetAvgRating
CREATE FUNCTION fGetAvgRating(parProdID VARCHAR(10)) 
RETURNS DECIMAL(3,1)
DETERMINISTIC
BEGIN
    DECLARE v_Avg DECIMAL(3,1);
    
    SELECT AVG(f.Rating) INTO v_Avg 
    FROM Feedback f 
    JOIN Sales s ON f.Sales_ID = s.Sales_ID 
    JOIN Sales_List sl ON s.Sales_ID = sl.Sales_ID 
    WHERE sl.Product_ID = parProdID;

    RETURN COALESCE(v_Avg, 0.0);
END //

-- fGetProductMargin
CREATE FUNCTION fGetProductMargin(parProdID VARCHAR(10)) 
RETURNS FLOAT(12, 2)
DETERMINISTIC
BEGIN
    DECLARE v_Sell  FLOAT(12, 2);
    DECLARE v_Cost  FLOAT(12, 2);
    
    SELECT Sell_Price INTO v_Sell 
    FROM Products 
    WHERE Product_ID = parProdID;

    SELECT AVG(Production_Cost) INTO v_Cost 
    FROM Production 
    WHERE Product_ID = parProdID;

    RETURN (v_Sell - COALESCE(v_Cost,0));
END //

-- fFormatCurrency
CREATE FUNCTION fFormatCurrency(parAmount  FLOAT(12, 2)) 
RETURNS VARCHAR(50)
DETERMINISTIC
BEGIN
    RETURN CONCAT('Rp. ', FORMAT(parAmount, 2));
END //

-- fGetWasteRatio
CREATE FUNCTION fGetWasteRatio(parProdID VARCHAR(10)) 
RETURNS DECIMAL(5,2)
DETERMINISTIC
BEGIN
    DECLARE v_Prod INT;
    DECLARE v_Waste INT;
    
    SELECT COALESCE(SUM(Quantity),0) INTO v_Prod 
    FROM Production 
    WHERE Product_ID = parProdID;

    SELECT COALESCE(SUM(w.Quantity),0) INTO v_Waste 
    FROM Waste w JOIN Production pr ON w.Production_ID = pr.Production_ID 
    WHERE pr.Product_ID = parProdID;

    IF v_Prod = 0 THEN RETURN 0.00; END IF;
    RETURN (v_Waste / v_Prod) * 100;
END //

  
/*==============================================================*/
/* PROCEDURE                                                    */
/*==============================================================*/
-- pRegisterCustomer
CREATE PROCEDURE pRegisterCustomer(IN parName VARCHAR(255), 
                                    IN parEmail VARCHAR(255), 
                                    IN parPass VARCHAR(255), 
                                    IN parPhone VARCHAR(20))
BEGIN
    DECLARE v_NewID VARCHAR(10);
    DECLARE v_Prefix VARCHAR(3);
    DECLARE v_Count INT;
    DECLARE v_Suffix VARCHAR(2);
    SET v_Prefix = UPPER(SUBSTRING(parName, 1, 3));

    SELECT COUNT(*) INTO v_Count 
    FROM Customers 
    WHERE Customer_ID 
    LIKE CONCAT(v_Prefix, '%');

    SET v_Suffix = LPAD(v_Count + 1, 2, '0');
    SET v_NewID = CONCAT(v_Prefix, v_Suffix);
    INSERT INTO Customers (Customer_ID, Customer_Name, Cust_Email, Cust_Password, Cust_Number, status_del) VALUES (v_NewID, parName, parEmail, md5(parPass), parPhone, 0);
    SELECT CONCAT('Registration Successful ID: ', v_NewID) AS Message;
END //

-- pUpdateProfile
CREATE PROCEDURE pUpdateProfile(IN parCustID VARCHAR(10), IN parNewEmail VARCHAR(255), IN parNewPhone VARCHAR(20))
BEGIN
    UPDATE Customers
    SET Cust_Email =
        CASE
            WHEN parNewEmail IS NULL OR parNewEmail = '' 
                THEN Cust_Email
            ELSE parNewEmail
        END,
        Cust_Number =
        CASE
            WHEN parNewPhone IS NULL OR parNewPhone = '' 
              THEN Cust_Number
            ELSE parNewPhone
        END
    WHERE Customer_ID = parCustID;

    SELECT 'Profile Updated Successfully' AS Message;
END //

-- pGetCustomerHistory
CREATE PROCEDURE pGetCustomerHistory(IN parCustID VARCHAR(10))
BEGIN
    SELECT s.Sales_ID, s.Date_Completed, p.Product_Name, sl.Quantity, sl.Total_Price 
    FROM Sales s 
    JOIN Sales_List sl ON s.Sales_ID = sl.Sales_ID 
    JOIN Products p ON sl.Product_ID = p.Product_ID 
    JOIN Orders o ON s.Orders_ID = o.Orders_ID 
    WHERE o.Customer_ID = parCustID 
    ORDER BY s.Date_Completed DESC;
END //

-- pAddNewProduct
CREATE PROCEDURE pAddNewProduct(IN parName VARCHAR(50), IN parPrice  FLOAT(12, 2))
BEGIN
    DECLARE v_NewID VARCHAR(10);
    DECLARE v_Count INT;

    SELECT COUNT(*) INTO v_Count 
    FROM Products;

    SET v_NewID = CONCAT('P', LPAD(v_Count + 1, 4, '0'));
    INSERT INTO Products (Product_ID, Product_Name, Sell_Price, status_del) VALUES (v_NewID, parName, parPrice, 0);
    SELECT CONCAT('Product Added: ', v_NewID) AS Message;
END //

-- pRecordProduction
CREATE PROCEDURE pRecordProduction(IN parProdID VARCHAR(10), IN parQty INT, IN parCost  FLOAT(12, 2))
BEGIN
    DECLARE v_NewID VARCHAR(10);
    DECLARE v_DateCode VARCHAR(6);
    DECLARE v_Count INT;
    SET v_DateCode = DATE_FORMAT(CURDATE(), '%d%m%y');

    SELECT COUNT(*) INTO v_Count 
    FROM Production 
    WHERE Date_In = CURDATE();

    SET v_NewID = CONCAT('PR', v_DateCode, LPAD(v_Count + 1, 2, '0'));
    INSERT INTO Production (Production_ID, Product_ID, Date_In, Quantity, Production_Cost, status_del) VALUES (v_NewID, parProdID, CURDATE(), parQty, parCost, 0);
    SELECT CONCAT('Production Recorded: ', v_NewID) AS Message;
END //

-- pRecordWaste
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

-- pCreateOrder
CREATE PROCEDURE pCreateOrder(IN parCustID VARCHAR(10))
BEGIN
    DECLARE v_NewID VARCHAR(10);
    DECLARE v_DateCode VARCHAR(6);
    DECLARE v_Count INT;
    DECLARE v_ActiveBatchID VARCHAR(10);

    SELECT Batch_ID INTO v_ActiveBatchID 
    FROM Batches 
    WHERE Status = 1 LIMIT 1;

    IF v_ActiveBatchID IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Pre-Order is CLOSED. Cannot place order now.';
    ELSE
        SET v_DateCode = DATE_FORMAT(CURDATE(), '%d%m%y');

        SELECT COUNT(*) INTO v_Count 
        FROM Orders 
        WHERE Order_For_Date = CURDATE();

        SET v_NewID = CONCAT('O', v_DateCode, LPAD(v_Count + 1, 2, '0'));

        INSERT INTO Orders (Orders_ID, Customer_ID, Batch_ID, Date_In, Order_Status, Order_For_Date, status_del)
        VALUES (v_NewID, parCustID, v_ActiveBatchID, CURDATE(), 0, CURDATE(), 0);

        SELECT CONCAT('Order Placed in ', v_ActiveBatchID) AS Message;
    END IF;
END //

-- pAddItemToOrder
CREATE PROCEDURE pAddItemToOrder(IN parOrderID VARCHAR(10), IN parProdID VARCHAR(10), IN parQty INT)
BEGIN
    DECLARE v_Status INT;

    SELECT Order_Status INTO v_Status 
    FROM Orders 
    WHERE Orders_ID = parOrderID;

    IF v_Status = 0 THEN
        INSERT INTO Order_List (Product_ID, Orders_ID, Quantity, Order_Date) 
        VALUES (parProdID, parOrderID, parQty, CURDATE());
        SELECT 'Item Added' AS Message;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot modify processed orders';
    END IF;
END //

-- pRemoveItemFromOrder
CREATE PROCEDURE pRemoveItemFromOrder(IN parOrderID VARCHAR(10), IN parProdID VARCHAR(10))
BEGIN
    DECLARE v_Status INT;

    SELECT Order_Status INTO v_Status
    FROM Orders
    WHERE Orders_ID = parOrderID;

    IF v_Status = 0 THEN
        UPDATE Order_List
        SET status_del = 1
        WHERE Orders_ID = parOrderID AND Product_ID = parProdID;

        SELECT 'Item Removed' AS Message;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot modify processed orders';
    END IF;
END //


-- pUpdateStatus
CREATE PROCEDURE pUpdateStatus(IN parOrderID VARCHAR(10), IN parNewStatus INT)
BEGIN
    UPDATE Orders 
    SET Order_Status = parNewStatus 
    WHERE Orders_ID = parOrderID;

    SELECT 'Status Updated' AS Message;
END //

-- pCheckoutTrans
CREATE PROCEDURE pCheckoutTrans(IN parOrderID VARCHAR(10), IN parPayment VARCHAR(15))
BEGIN
    DECLARE v_SalesID VARCHAR(10);
    DECLARE v_DateCode VARCHAR(6);
    DECLARE v_Count INT;
    DECLARE v_Suffix VARCHAR(2);
    SET v_DateCode = DATE_FORMAT(CURDATE(), '%d%m%y');

    SELECT COUNT(*) INTO v_Count 
    FROM Sales 
    WHERE Date_Completed = CURDATE();

    SET v_Suffix = LPAD(v_Count + 1, 2, '0');
    SET v_SalesID = CONCAT('S', v_DateCode, v_Suffix);

    INSERT INTO Sales (Sales_ID, Orders_ID, Date_Completed, Payment, status_del) 
    VALUES (v_SalesID, parOrderID, CURDATE(), parPayment, 0);

    INSERT INTO Sales_List (Product_ID, Sales_ID, Quantity, Total_Price) 
    SELECT ol.Product_ID, v_SalesID, ol.Quantity, (ol.Quantity * p.Sell_Price) FROM Order_List ol JOIN Products p ON ol.Product_ID = p.Product_ID WHERE ol.Orders_ID = parOrderID;
    SELECT 'Successfully added to Sales' AS Message;
END //

-- pSubmitReview
CREATE PROCEDURE pSubmitReview(IN parCustID VARCHAR(10), IN parSalesID VARCHAR(10), IN parRating INT, IN parComment TEXT)
BEGIN
    DECLARE v_Check INT;
    DECLARE v_FeedbackID VARCHAR(10);
    DECLARE v_CustInitials VARCHAR(3);
    DECLARE v_Count INT;
    DECLARE v_Suffix VARCHAR(2);

    SELECT COUNT(*) INTO v_Check 
    FROM Sales 
    WHERE Sales_ID = parSalesID;

    IF v_Check > 0 THEN
        SELECT UPPER(SUBSTRING(Customer_Name, 1, 3)) INTO v_CustInitials 
        FROM Customers 
        WHERE Customer_ID = parCustID;

        SELECT COUNT(*) INTO v_Count 
        FROM Feedback 
        WHERE Feedback_ID LIKE CONCAT('F', v_CustInitials, '%');

        SET v_Suffix = LPAD(v_Count + 1, 2, '0');
        SET v_FeedbackID = CONCAT('F', v_CustInitials, v_Suffix);

        INSERT INTO Feedback (Feedback_ID, Sales_ID, Customer_ID, Feedback_comment, Rating, status_del) 
        VALUES (v_FeedbackID, parSalesID, parCustID, parComment, parRating, 0);
        SELECT 'Successfully submitted to Feedback' AS Message;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sales ID not found';
    END IF;
END //

-- pOrderGenID
CREATE PROCEDURE pOrderGenID(IN parDate DATE, OUT parID VARCHAR(15))
BEGIN
    DECLARE v_DateCode VARCHAR(6);
    DECLARE v_Count INT;
    DECLARE v_Suffix VARCHAR(2);
    SET v_DateCode = DATE_FORMAT(parDate, '%d%m%y');

    SELECT COUNT(*) INTO v_Count 
    FROM Orders 
    WHERE Order_For_Date = parDate;

    SET v_Suffix = LPAD(v_Count + 1, 2, '0');
    SET parID = CONCAT('O', v_DateCode, v_Suffix);
END //

-- pOpenBatch
CREATE PROCEDURE pOpenBatch(IN parName VARCHAR(50), IN parCloseDate DATETIME, IN parDeliveryDate DATE)
BEGIN
    DECLARE v_NewID VARCHAR(10);
    DECLARE v_DateCode VARCHAR(6);
    DECLARE v_Count INT;
    DECLARE v_CheckActive INT;

    SELECT COUNT(*) INTO v_CheckActive 
    FROM Batches 
    WHERE Status = 1;

    IF v_CheckActive > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: A Batch is already OPEN. Close it first.';
    ELSE
        SET v_DateCode = DATE_FORMAT(NOW(), '%d%m%y');

        SELECT COUNT(*) INTO v_Count 
        FROM Batches 
        WHERE DATE(Open_Date) = CURDATE();

        SET v_NewID = CONCAT('B', v_DateCode, LPAD(v_Count + 1, 2, '0'));

        INSERT INTO Batches (Batch_ID, Batch_Name, Open_Date, Close_Date, Delivery_Date, Status, status_del)
        VALUES (v_NewID, parName, NOW(), parCloseDate, parDeliveryDate, 1, 0);

        SELECT CONCAT('Pre-Order Started: ', v_NewID) AS Message;
    END IF;
END //

-- pCloseBatch
CREATE PROCEDURE pCloseBatch()
BEGIN
    DECLARE v_BatchID VARCHAR(10);

    SELECT Batch_ID INTO v_BatchID 
    FROM Batches 
    WHERE Status = 1 LIMIT 1;

    IF v_BatchID IS NOT NULL THEN
        UPDATE Batches
        SET Close_Date = NOW(), Status = 0
        WHERE Batch_ID = v_BatchID;
        SELECT CONCAT('Pre-Order Closed for: ', v_BatchID) AS Message;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: No Open Batch found.';
    END IF;
END //
  
/*==============================================================*/
/* TRIGGER                                                      */
/*==============================================================*/
-- tAutoFillWaste
CREATE TRIGGER tAutoFillWaste
BEFORE INSERT 
ON Waste
FOR EACH ROW
BEGIN
    DECLARE v_ProdID VARCHAR(5);
    DECLARE v_Price FLOAT;

    SELECT Product_ID, Production_Cost INTO v_ProdID, v_Price
    FROM Production
    WHERE Production_ID = NEW.Production_ID;

    SET NEW.Product_ID = v_ProdID;
    SET NEW.Price = v_Price;
END //

-- tStockCheck
CREATE TRIGGER tStockCheck 
BEFORE INSERT 
ON Sales_List 
FOR EACH ROW
BEGIN
    IF fLiveStock(NEW.Product_ID) < NEW.Quantity THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Insufficient Stock available';
    END IF;
END //

-- tCheckRating
CREATE TRIGGER tCheckRating 
BEFORE INSERT 
ON Feedback 
FOR EACH ROW
BEGIN
    IF NEW.Rating < 1 THEN SET NEW.Rating = 1; END IF;
    IF NEW.Rating > 5 THEN SET NEW.Rating = 5; END IF;
END //

-- tCloseOrder
CREATE TRIGGER tCloseOrder 
AFTER INSERT 
ON Sales 
FOR EACH ROW
BEGIN
    UPDATE Orders SET Order_Status = 2 WHERE Orders_ID = NEW.Orders_ID;
END //

-- tAutoPrice
CREATE TRIGGER tAutoPrice 
BEFORE INSERT 
ON Sales_List 
FOR EACH ROW
BEGIN
    DECLARE v_Price  FLOAT(12, 2);
    SELECT Sell_Price INTO v_Price FROM Products WHERE Product_ID = NEW.Product_ID;
    SET NEW.Total_Price = NEW.Quantity * v_Price;
END //

-- tPreventFutureDate
CREATE TRIGGER tPreventFutureDate 
BEFORE INSERT 
ON Orders 
FOR EACH ROW
BEGIN
    IF NEW.Date_In > CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Cannot create order in future';
    END IF;
END //

-- tEnsureValidEmail
CREATE TRIGGER tEnsureValidEmail 
BEFORE INSERT 
ON Customers 
FOR EACH ROW
BEGIN
    IF NEW.Cust_Email NOT LIKE '%@%' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Invalid Email Address';
    END IF;
END //

-- tPreventDeleteActiveCustomer
CREATE TRIGGER tPreventDeleteActiveCustomer 
BEFORE UPDATE 
ON Customers 
FOR EACH ROW
BEGIN
    DECLARE v_ActiveOrders INT;
    IF NEW.status_del = 1 THEN
        SELECT COUNT(*) INTO v_ActiveOrders FROM Orders WHERE Customer_ID = NEW.Customer_ID AND Order_Status != 2;
        IF v_ActiveOrders > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Cannot delete customer with active orders';
        END IF;
    END IF;
END //




DELIMITER ;
