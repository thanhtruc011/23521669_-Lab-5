USE MASTER
GO
CREATE DATABASE BAITHI;
DROP DATABASE BAITHI;
USE BAITHI;
--Câu 1
CREATE TABLE NHANVIEN (
MaNV char(5) PRIMARY KEY,
HoTen varchar(20),
NgayVL smalldatetime,
HSLuong numeric(4, 2),
MaPhong char(5)
)
CREATE TABLE PHONGBAN(
MaPhong char(5) PRIMARY KEY,
TenPhong varchar(25),
TruongPhong char(5)
)
CREATE TABLE XE(
MaXe char(5) PRIMARY KEY,
LoaiXe varchar(20),
SoChoNgoi int,
NamSX int
)
CREATE TABLE PHANCONG(
MaPC char(5),
MaNV char(5),
MaXe char(5),
NgayDi smalldatetime,
Ngayve smalldatetime,
NoiDen varchar(25),
PRIMARY KEY(MaPC, MaNV, MaXe),
FOREIGN KEY (MaNV) REFERENCES NHANVIEN(MaNV),
FOREIGN KEY (MaXe) REFERENCES XE (MaXe)
)
--Câu 2.1
ALTER TABLE XE 
ADD CONSTRAINT check_NamSX CHECK (Loaixe = 'Toyota' AND NamSX >=2006)
--Câu 2.2 
CREATE TRIGGER trg_CheckNgoaiThanh
ON PHANCONG
AFTER INSERT, UPDATE
AS
BEGIN
    -- Kiểm tra nếu nhân viên thuộc phòng "Ngoại thành" lái xe không phải Toyota
    IF EXISTS (
        SELECT 1
        FROM PHANCONG PC
        JOIN XE X ON PC.MaXe = X.MaXe
        JOIN NHANVIEN NV ON PC.MaNV = NV.MaNV
        JOIN PHONGBAN PB ON NV.MaPhong = PB.MaPhong
        WHERE PB.TenPhong = 'Ngoại thành' AND X.LoaiXe != 'Toyota'
    )
    BEGIN
        RAISERROR ('Nhân viên phòng Ngoại thành chỉ được phân công xe Toyota.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
--Câu 3.1
SELECT a.MaNV,a.HoTen
FROM NHANVIEN a
JOIN PHONGBAN d ON d.MaPhong = a.MaPhong
JOIN PHANCONG b ON b.MaNV = a.MaNV 
JOIN XE c ON c.MaXe = b.MaXe
WHERE d.TenPhong = 'Noi thanh' AND c.LoaiXe = 'Toyota' AND c.SoChoNgoi =4;
--Câu 3.2
SELECT DISTINCT NV.MaNV, NV.HoTen
FROM NHANVIEN NV
JOIN PHONGBAN PB ON NV.MaPhong = PB.MaPhong
JOIN PHANCONG PC ON NV.MaNV = PC.MaNV
JOIN XE X ON PC.MaXe = X.MaXe
WHERE PB.TruongPhong = NV.MaNV
GROUP BY NV.MaNV, NV.HoTen
HAVING COUNT(DISTINCT X.MaXe) = (SELECT COUNT(*) FROM XE);
--Câu 3.3
SELECT DISTINCT NV.MaNV, NV.HoTen
FROM NHANVIEN NV
JOIN PHONGBAN PB ON NV.MaPhong = PB.MaPhong
JOIN PHANCONG PC ON NV.MaNV = PC.MaNV
JOIN XE X ON PC.MaXe = X.MaXe
WHERE X.LoaiXe = 'Toyota';


 
