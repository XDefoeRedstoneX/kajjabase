use kajjabase;
DELIMITER//

CREATE FUNCTION fLiveStock(parProdID VARCHAR(10)) RETURNS INT
    DETERMINISTIC
BEGIN
    DECLARE v_Prod INT DEFAULT 0;
    DECLARE v_Sold INT DEFAULT 0;
    DECLARE v_Waste INT DEFAULT 0;
    SELECT COALESCE(SUM(Quantity),0) INTO v_Prod FROM Production WHERE Product_ID = parProdID;
    SELECT COALESCE(SUM(Quantity),0) INTO v_Sold FROM Sales_List WHERE Product_ID = parProdID;
    SELECT COALESCE(SUM(Quantity),0) INTO v_Waste FROM Waste WHERE Product_ID = parProdID;
    RETURN (v_Prod - v_Sold - v_Waste);
END //
CREATE FUNCTION fEstCartTotal(parOrderID VARCHAR(10)) RETURNS  FLOAT(12, 2)
    DETERMINISTIC
BEGIN
    DECLARE v_Total  FLOAT(12, 2);
    SELECT SUM(ol.Quantity * p.Sell_Price) INTO v_Total FROM Order_List ol JOIN Products p ON ol.Product_ID = p.Product_ID
    WHERE ol.Orders_ID = parOrderID;
    RETURN COALESCE(v_Total, 0.00);
END //

CREATE FUNCTION fGenCustID(parCustName VARCHAR(255)) RETURNS VARCHAR(10)
    DETERMINISTIC
BEGIN
    DECLARE v_Prefix VARCHAR(3);
    DECLARE v_Count INT;
    DECLARE v_Suffix VARCHAR(2);
    SET v_Prefix = UPPER(SUBSTRING(parCustName, 1, 3));
    SELECT COUNT(*) INTO v_Count FROM Customers WHERE Customer_ID LIKE CONCAT(v_Prefix, '%');
    SET v_Suffix = LPAD(v_Count + 1, 2, '0');
    RETURN CONCAT(v_Prefix, v_Suffix);
END //

CREATE FUNCTION fGetAvgRating(parProdID VARCHAR(10)) RETURNS DECIMAL(3,1)
    DETERMINISTIC
BEGIN
    DECLARE v_Avg DECIMAL(3,1);
    SELECT AVG(f.Rating) INTO v_Avg FROM Feedback f JOIN Sales s ON f.Sales_ID = s.Sales_ID JOIN Sales_List sl ON s.Sales_ID = sl.Sales_ID WHERE sl.Product_ID = parProdID;
    RETURN COALESCE(v_Avg, 0.0);
END //

CREATE FUNCTION fGetProductMargin(parProdID VARCHAR(10)) RETURNS  FLOAT(12, 2)
    DETERMINISTIC
BEGIN
    DECLARE v_Sell  FLOAT(12, 2);
    DECLARE v_Cost  FLOAT(12, 2);
    SELECT Sell_Price INTO v_Sell FROM Products WHERE Product_ID = parProdID;
    SELECT AVG(Production_Cost) INTO v_Cost FROM Production WHERE Product_ID = parProdID;
    RETURN (v_Sell - COALESCE(v_Cost,0));
END //

CREATE FUNCTION fFormatCurrency(parAmount  FLOAT(12, 2)) RETURNS VARCHAR(50)
    DETERMINISTIC
BEGIN
    RETURN CONCAT('Rp. ', FORMAT(parAmount, 2));
END //

CREATE FUNCTION fGetWasteRatio(parProdID VARCHAR(10)) RETURNS DECIMAL(5,2)
    DETERMINISTIC
BEGIN
    DECLARE v_Prod INT;
    DECLARE v_Waste INT;
    SELECT COALESCE(SUM(Quantity),0) INTO v_Prod FROM Production WHERE Product_ID = parProdID;
    SELECT COALESCE(SUM(w.Quantity),0) INTO v_Waste FROM Waste w JOIN Production pr ON w.Production_ID = pr.Production_ID WHERE pr.Product_ID = parProdID;
    IF v_Prod = 0 THEN RETURN 0.00; END IF;
    RETURN (v_Waste / v_Prod) * 100;
END //

DELIMITER ;