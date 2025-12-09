use kajjabase;

CREATE OR REPLACE VIEW vSalesToday AS
    SELECT s.Sales_ID, s.Date_Completed,
           SUM(sl.Total_Price) as Daily_Revenue FROM Sales s
               JOIN Sales_List sl ON s.Sales_ID = sl.Sales_ID
        WHERE s.Date_Completed = CURDATE()
        GROUP BY s.Sales_ID, s.Date_Completed;

CREATE OR REPLACE VIEW vBestCustomers AS
    SELECT c.Customer_Name, COUNT(DISTINCT s.Sales_ID) as Total_Transactions,
           SUM(sl.Total_Price) as Total_Value FROM Customers c
               JOIN Orders o ON c.Customer_ID = o.Customer_ID
               JOIN Sales s ON o.Orders_ID = s.Orders_ID
               JOIN Sales_List sl ON s.Sales_ID = sl.Sales_ID
WHERE c.status_del = 0
GROUP BY c.Customer_ID, c.Customer_Name;

CREATE OR REPLACE VIEW vPendingOrder AS
    SELECT o.Orders_ID, c.Customer_Name, o.Order_For_Date, o.Order_Status FROM Orders o
        JOIN Customers c ON o.Customer_ID = c.Customer_ID
        LEFT JOIN Sales s ON o.Orders_ID = s.Orders_ID
        WHERE s.Sales_ID IS NULL AND o.status_del = 0;

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


CREATE OR REPLACE VIEW vTopSellingProducts AS
    SELECT p.Product_Name, SUM(sl.Quantity) as Units_Sold FROM Products p
        JOIN Sales_List sl ON p.Product_ID = sl.Product_ID
GROUP BY p.Product_Name
ORDER BY Units_Sold DESC;

-- Run after fLiveStock
CREATE OR REPLACE VIEW vLowStockAlert AS
SELECT p.Product_ID, p.Product_Name, fLiveStock(p.Product_ID) as Current_Stock
FROM Products p WHERE fLiveStock(p.Product_ID) < 10;