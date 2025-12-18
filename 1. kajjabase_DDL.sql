DROP DATABASE IF EXISTS kajjabase;
CREATE DATABASE kajjabase;
USE kajjabase;

CREATE TABLE Customers (
    Customer_ID VARCHAR(10) PRIMARY KEY,
    Customer_Name VARCHAR(50) NOT NULL,
    Cust_Email VARCHAR(50) NOT NULL,
    Cust_Password VARCHAR(255) NOT NULL,
    Cust_Number VARCHAR(20) NOT NULL,
    status_del INT DEFAULT 0
);

CREATE TABLE Products (
    Product_ID VARCHAR(5) PRIMARY KEY,
    Product_Name VARCHAR(50) NOT NULL,
    Sell_Price FLOAT(12, 2) NOT NULL,
    status_del INT DEFAULT 0
);

CREATE TABLE Batches (
	Batch_ID VARCHAR(10) PRIMARY KEY,
	Batch_Name VARCHAR(50) NOT NULL,
	Open_Date DATETIME NOT NULL,
	Close_Date DATETIME NOT NULL,
	Delivery_Date Date NOT NULL,
	Status INT DEFAULT 1,
	status_del INT DEFAULT 0
);


CREATE TABLE Orders (
    Orders_ID VARCHAR(10) PRIMARY KEY,
    Customer_ID VARCHAR(10) NOT NULL,
    Batch_ID VARCHAR(10)NOT NULL,
    Date_In DATE NOT NULL,
    Order_Status INT DEFAULT 0,
    Order_For_Date DATE NOT NULL,
    status_del INT DEFAULT 0,
    FOREIGN KEY (Customer_ID) REFERENCES Customers(Customer_ID),
    FOREIGN KEY (Batch_ID) REFERENCES Batches(Batch_ID)
);


CREATE TABLE Order_List (
    Product_ID VARCHAR(5) NOT NULL,
    Orders_ID VARCHAR(10) NOT NULL,
    Quantity INT NOT NULL,
    Order_Date DATE NOT NULL,
    status_del INT DEFAULT 0,
    PRIMARY KEY (Product_ID, Orders_ID),
    FOREIGN KEY (Product_ID) REFERENCES Products(Product_ID),
    FOREIGN KEY (Orders_ID) REFERENCES Orders(Orders_ID)
);

CREATE TABLE Sales (
    Sales_ID VARCHAR(10) PRIMARY KEY,
    Orders_ID VARCHAR(10) NOT NULL,
    Date_Completed DATE NOT NULL,
    Payment VARCHAR(15) NOT NULL,
    status_del INT DEFAULT 0,
    FOREIGN KEY (Orders_ID) REFERENCES Orders(Orders_ID)
);

CREATE TABLE Sales_List (
    Product_ID VARCHAR(5) NOT NULL,
    Sales_ID VARCHAR(10) NOT NULL,
    Quantity INT NOT NULL,
    Total_Price  FLOAT(12, 2) NOT NULL,
    status_del INT DEFAULT 0,
    PRIMARY KEY (Product_ID, Sales_ID),
    FOREIGN KEY (Product_ID) REFERENCES Products(Product_ID),
    FOREIGN KEY (Sales_ID) REFERENCES Sales(Sales_ID)
);

CREATE TABLE Production (
	Production_ID VARCHAR(10) PRIMARY KEY,
	Product_ID VARCHAR(5) NOT NULL,
	Date_In DATE NOT NULL,
	Quantity INT NOT NULL,
	Production_Cost  FLOAT(12, 2) NOT NULL,
	status_del INT DEFAULT 0,
	FOREIGN KEY (Product_ID) REFERENCES Products(Product_ID)
);

CREATE TABLE Waste (
    Waste_ID VARCHAR(10) PRIMARY KEY,
    Production_ID VARCHAR(10) NOT NULL,
    Product_ID VARCHAR(5) NOT NULL,
    Quantity INT NOT NULL,
    Price  FLOAT(12, 2) NOT NULL,
    status_del INT DEFAULT 0,
    FOREIGN KEY (Production_ID) REFERENCES Production(Production_ID),
    FOREIGN KEY (Product_ID) REFERENCES Products(Product_ID)
);

CREATE TABLE Feedback (
    Feedback_ID VARCHAR(10) PRIMARY KEY,
    Sales_ID VARCHAR(10) NOT NULL,
    Customer_ID VARCHAR(10) NOT NULL,
    feedback_comment TEXT,
    Rating INT NOT NULL,
    status_del INT DEFAULT 0,
    FOREIGN KEY (Sales_ID) REFERENCES Sales(Sales_ID),
    FOREIGN KEY (Customer_ID) REFERENCES Customers(Customer_ID)
);

