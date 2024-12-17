USE QLGV
GO

-- 1. Drop các trigger nếu đã tồn tại
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'TR' AND name = 'trg_ins_udt_LopTruong')
    DROP TRIGGER trg_ins_udt_LopTruong;
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'TR' AND name = 'trg_del_HOCVIEN')
    DROP TRIGGER trg_del_HOCVIEN;
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'TR' AND name = 'TRG_UPDATE_GIAOVIEN')
    DROP TRIGGER TRG_UPDATE_GIAOVIEN;
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'TR' AND name = 'TRG10_DELETE_GIAOVIEN')
    DROP TRIGGER TRG10_DELETE_GIAOVIEN;
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'TR' AND name = 'TRG16_INSERT_GIANGDAY')
    DROP TRIGGER TRG16_INSERT_GIANGDAY;
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'TR' AND name = 'TRG17_INSERT_LOP')
    DROP TRIGGER TRG17_INSERT_LOP;
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'TR' AND name = 'TRG19_INSERTED_GIAOVIEN')
    DROP TRIGGER TRG19_INSERTED_GIAOVIEN;
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'TR' AND name = 'TRG20_INSERT_KQT')
    DROP TRIGGER TRG20_INSERT_KQT;
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'TR' AND name = 'TRG21_INSERT_KQT')
    DROP TRIGGER TRG21_INSERT_KQT;
GO

-- 2. Trigger: Lớp trưởng của một lớp phải là học viên của lớp đó
CREATE TRIGGER trg_ins_udt_LopTruong ON LOP
FOR INSERT, UPDATE
AS
BEGIN
    IF NOT EXISTS (SELECT 1 FROM INSERTED I
                   JOIN HOCVIEN HV ON I.TruongLop = HV.MaHocVien AND I.MALOP = HV.MALOP)
    BEGIN
        PRINT 'Error: Lop truong cua mot lop phai la hoc vien cua lop do'
        ROLLBACK TRANSACTION
    END
END;
GO

-- 3. Trigger: Không được xóa học viên nếu họ là lớp trưởng
CREATE TRIGGER trg_del_HOCVIEN ON HOCVIEN
FOR DELETE
AS
BEGIN
    IF EXISTS (SELECT 1 FROM DELETED D
               JOIN LOP L ON D.MaHocVien = L.TruongLop AND D.MALOP = L.MALOP)
    BEGIN
        PRINT 'Error: Hoc vien hien tai dang la truong lop'
        ROLLBACK TRANSACTION
    END
END;
GO

-- 4. Trigger: Cập nhật thông tin giáo viên khi là trưởng khoa
CREATE TRIGGER TRG_UPDATE_GIAOVIEN ON GIAOVIEN
FOR UPDATE
AS
BEGIN
    IF (SELECT COUNT(*)
        FROM INSERTED I
        JOIN KHOA K ON I.MaGiaoVien = K.TruongKhoa AND I.MAKHOA = K.MAKHOA) = 0
    BEGIN
        PRINT 'ERROR: Giao vien phai la truong khoa cua khoa'
        ROLLBACK TRANSACTION
    END
    ELSE
    BEGIN
        PRINT 'THANH CONG'
    END
END;
GO

-- 5. Trigger: Không được xóa giáo viên nếu là trưởng khoa
CREATE TRIGGER TRG10_DELETE_GIAOVIEN ON GIAOVIEN
FOR DELETE
AS
BEGIN
    DECLARE @MAGV CHAR(4), @TRGKHOA CHAR(4), @MAKHOA VARCHAR(4)
    SELECT @MAGV = MaGiaoVien, @MAKHOA = MAKHOA
    FROM DELETED
    SELECT @TRGKHOA = TruongKhoa
    FROM KHOA
    WHERE MAKHOA = @MAKHOA
    IF (@MAGV = @TRGKHOA)
    BEGIN
        PRINT 'Khong duoc xoa giao vien la truong khoa'
        ROLLBACK TRANSACTION
    END
    ELSE
    BEGIN
        PRINT 'Xoa thanh cong!'
    END
END;
GO

-- 6. Trigger: Giới hạn số môn học mỗi lớp có thể học trong một học kỳ
CREATE TRIGGER TRG16_INSERT_GIANGDAY ON GIANGDAY
FOR INSERT, UPDATE
AS
BEGIN
    IF (SELECT COUNT(*)
        FROM INSERTED I
        JOIN GIANGDAY GD ON I.MALOP = GD.MALOP AND I.HOCKY = GD.HOCKY) > 3
    BEGIN
        PRINT 'ERROR: Moi hoc ky khong duoc qua 3 mon'
        ROLLBACK TRANSACTION
    END
    ELSE
    BEGIN
        PRINT 'THANH CONG'
    END
END;
GO

-- 7. Trigger: Kiểm tra sĩ số lớp
CREATE TRIGGER TRG17_INSERT_LOP ON LOP
FOR INSERT, UPDATE
AS
BEGIN
    DECLARE @SISO TINYINT, @DEMHOCVIEN TINYINT, @MALOP CHAR(3)
    SELECT @SISO = SISO, @MALOP = MALOP
    FROM INSERTED
    SELECT @DEMHOCVIEN = COUNT(MaHocVien)
    FROM HOCVIEN
    WHERE MALOP = @MALOP
    IF (@SISO <> @DEMHOCVIEN)
    BEGIN
        PRINT 'Khong cho sua si so'
        ROLLBACK TRANSACTION
    END
    ELSE
    BEGIN
        PRINT 'Sua si so thanh cong'
    END
END;
GO

-- 8. Trigger: Giáo viên có cùng học vị, học hàm, hệ số lương thì mức lương phải bằng nhau
CREATE TRIGGER TRG19_INSERTED_GIAOVIEN ON GIAOVIEN
FOR INSERT, UPDATE
AS
BEGIN
    IF (SELECT COUNT(*)
        FROM INSERTED I
        JOIN GIAOVIEN GV ON I.HOCHAM = GV.HOCHAM AND I.HOCVI = GV.HOCVI AND I.HESO = GV.HESO
        AND I.MUCLUONG != GV.MUCLUONG) > 0
    BEGIN
        PRINT 'ERROR: Muc luong cua giao vien phai giong nhau'
        ROLLBACK TRAN
    END
    ELSE
    BEGIN
        PRINT 'THANH CONG'
    END
END;
GO

-- 9. Trigger: Điểm thi lại phải dưới 5
CREATE TRIGGER TRG20_INSERT_KQT ON KETQUATHI
FOR INSERT
AS
BEGIN
    DECLARE @LANTHI TINYINT, @MAHV CHAR(5), @DIEM NUMERIC(4,2)
    SELECT @LANTHI = KETQUATHI.LANTHI + 1, @MAHV = I.MaHocVien, @DIEM = KETQUATHI.DIEM
    FROM INSERTED I
    JOIN KETQUATHI ON I.MaHocVien = KETQUATHI.MaHocVien
    WHERE I.MaMonHoc = KETQUATHI.MaMonHoc
    IF (@DIEM > 5)
    BEGIN
        PRINT 'Khong duoc thi lan nua!'
        ROLLBACK TRANSACTION
    END
    ELSE
    BEGIN
        PRINT 'Them lan thi thanh cong!'
    END
END;
GO

-- 10. Trigger: Ngày thi của lần thi sau phải lớn hơn ngày thi của lần thi trước
CREATE TRIGGER TRG21_INSERT_KQT ON KETQUATHI
FOR INSERT, UPDATE
AS
BEGIN
    IF (SELECT COUNT(*)
        FROM INSERTED I
        JOIN KETQUATHI K ON I.LANTHI > K.LANTHI
        AND I.MaHocVien = K.MaHocVien AND I.MaMonHoc = I.MaMonHoc AND I.NgayThi > K.NgayThi) = 0
    BEGIN
        PRINT 'ERROR: Ngay thi cua lan sau phai lon hon lan thi truoc'
        ROLLBACK TRAN
    END
    ELSE
    BEGIN
        PRINT 'THANH CONG'
    END
END;
GO
