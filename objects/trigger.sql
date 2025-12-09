use kajjabase;
DELIMITER //

CREATE TRIGGER tAutoFillWaste
    BEFORE INSERT ON Waste
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

CREATE TRIGGER tStockCheck BEFORE INSERT ON Sales_List FOR EACH ROW
BEGIN
    IF fLiveStock(NEW.Product_ID) < NEW.Quantity THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Insufficient Stock available';
    END IF;
END //

CREATE TRIGGER tCheckRating BEFORE INSERT ON Feedback FOR EACH ROW
BEGIN
    IF NEW.Rating < 1 THEN SET NEW.Rating = 1; END IF;
    IF NEW.Rating > 5 THEN SET NEW.Rating = 5; END IF;
END //

CREATE TRIGGER tCloseOrder AFTER INSERT ON Sales FOR EACH ROW
BEGIN
    UPDATE Orders SET Order_Status = 2 WHERE Orders_ID = NEW.Orders_ID;
END //

CREATE TRIGGER tAutoPrice BEFORE INSERT ON Sales_List FOR EACH ROW
BEGIN
    DECLARE v_Price  FLOAT(12, 2);
    SELECT Sell_Price INTO v_Price FROM Products WHERE Product_ID = NEW.Product_ID;
    SET NEW.Total_Price = NEW.Quantity * v_Price;
END //

CREATE TRIGGER tPreventFutureDate BEFORE INSERT ON Orders FOR EACH ROW
BEGIN
    IF NEW.Date_In > CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Cannot create order in future';
    END IF;
END //

CREATE TRIGGER tEnsureValidEmail BEFORE INSERT ON Customers FOR EACH ROW
BEGIN
    IF NEW.Cust_Email NOT LIKE '%@%' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Invalid Email Address';
    END IF;
END //

CREATE TRIGGER tPreventDeleteActiveCustomer BEFORE UPDATE ON Customers FOR EACH ROW
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