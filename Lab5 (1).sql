USE CHUYENGIA

-- Câu hỏi và ví dụ về Triggers (101-110)

-- 101. Tạo một trigger để tự động cập nhật trường NgayCapNhat trong bảng ChuyenGia mỗi khi có sự thay đổi thông tin.
GO

ALTER TABLE ChuyenGia
ADD NgayCapNhat DATETIME;
GO
CREATE TRIGGER trg_UpdateNgayCapNhat
ON ChuyenGia
AFTER UPDATE
AS
BEGIN
    -- Update the NgayCapNhat field with the current date and time whenever a record is updated
    UPDATE ChuyenGia
    SET NgayCapNhat = GETDATE()
    FROM ChuyenGia c
    INNER JOIN inserted i ON c.MaChuyenGia = i.MaChuyenGia;
END;
GO



-- 102. Tạo một trigger để ghi log mỗi khi có sự thay đổi trong bảng DuAn.
CREATE TABLE DuAn_Log (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    MaDuAn INT,
    TenDuAn NVARCHAR(200),
    MaCongTy INT,
    NgayBatDau DATE,
    NgayKetThuc DATE,
    TrangThai NVARCHAR(50),
    ActionType NVARCHAR(10),  -- Insert, Update, Delete
    ActionDate DATETIME DEFAULT GETDATE()
);
GO

CREATE TRIGGER trg_LogDuAnChanges
ON DuAn
FOR INSERT, UPDATE, DELETE
AS
BEGIN
    -- Log the INSERT actions
    IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT INTO DuAn_Log (MaDuAn, TenDuAn, MaCongTy, NgayBatDau, NgayKetThuc, TrangThai, ActionType)
        SELECT MaDuAn, TenDuAn, MaCongTy, NgayBatDau, NgayKetThuc, TrangThai, 'INSERT'
        FROM inserted;
    END

    -- Log the DELETE actions
    IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO DuAn_Log (MaDuAn, TenDuAn, MaCongTy, NgayBatDau, NgayKetThuc, TrangThai, ActionType)
        SELECT MaDuAn, TenDuAn, MaCongTy, NgayBatDau, NgayKetThuc, TrangThai, 'DELETE'
        FROM deleted;
    END

    -- Log the UPDATE actions
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO DuAn_Log (MaDuAn, TenDuAn, MaCongTy, NgayBatDau, NgayKetThuc, TrangThai, ActionType)
        SELECT MaDuAn, TenDuAn, MaCongTy, NgayBatDau, NgayKetThuc, TrangThai, 'UPDATE'
        FROM inserted;
    END
END;
GO


-- 103. Tạo một trigger để đảm bảo rằng một chuyên gia không thể tham gia vào quá 5 dự án cùng một lúc.
GO  -- To separate the batches

CREATE TRIGGER trg_CheckMaxProjects
ON ChuyenGia_DuAn
AFTER INSERT
AS
BEGIN
    DECLARE @MaChuyenGia INT;
    DECLARE @CountActiveProjects INT;

    -- Get the MaChuyenGia of the new record inserted into ChuyenGia_DuAn
    SELECT @MaChuyenGia = MaChuyenGia FROM inserted;

    -- Count the number of active projects for the specialist (based only on NgayThamGia)
    SELECT @CountActiveProjects = COUNT(*)
    FROM ChuyenGia_DuAn
    WHERE MaChuyenGia = @MaChuyenGia
      AND NgayThamGia <= GETDATE();

    -- Check if the specialist is already involved in 5 or more active projects
    IF @CountActiveProjects >= 5
    BEGIN
        -- If the limit is exceeded, raise an error and roll back the insert
        RAISERROR ('A specialist cannot participate in more than 5 projects at the same time.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

-- 104. Tạo một trigger để tự động cập nhật số lượng nhân viên trong bảng CongTy mỗi khi có sự thay đổi trong bảng ChuyenGia.
-- Thêm cột MaCongTy vào bảng ChuyenGia
ALTER TABLE ChuyenGia
ADD MaCongTy INT;

-- Add a foreign key to ensure the company exists in the CongTy table
ALTER TABLE ChuyenGia
ADD CONSTRAINT FK_ChuyenGia_CongTy FOREIGN KEY (MaCongTy) REFERENCES CongTy(MaCongTy);
GO  -- Separate the batch

CREATE TRIGGER trg_UpdateEmployeeCount
ON ChuyenGia
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    -- Handle inserts: Count employees for the new company
    IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        UPDATE CongTy
        SET SoNhanVien = (
            SELECT COUNT(*) FROM ChuyenGia WHERE MaCongTy = inserted.MaCongTy
        )
        FROM inserted
        WHERE CongTy.MaCongTy = inserted.MaCongTy;
    END;

    -- Handle updates: Recount for both the old and new companies
    IF EXISTS (SELECT 1 FROM deleted) AND EXISTS (SELECT 1 FROM inserted)
    BEGIN
        -- Update the old company
        UPDATE CongTy
        SET SoNhanVien = (
            SELECT COUNT(*) FROM ChuyenGia WHERE MaCongTy = deleted.MaCongTy
        )
        FROM deleted
        WHERE CongTy.MaCongTy = deleted.MaCongTy;

        -- Update the new company
        UPDATE CongTy
        SET SoNhanVien = (
            SELECT COUNT(*) FROM ChuyenGia WHERE MaCongTy = inserted.MaCongTy
        )
        FROM inserted
        WHERE CongTy.MaCongTy = inserted.MaCongTy;
    END;

    -- Handle deletions: Recount employees for the old company
    IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        UPDATE CongTy
        SET SoNhanVien = (
            SELECT COUNT(*) FROM ChuyenGia WHERE MaCongTy = deleted.MaCongTy
        )
        FROM deleted
        WHERE CongTy.MaCongTy = deleted.MaCongTy;
    END;
END;
GO


-- 105. Tạo một trigger để ngăn chặn việc xóa các dự án đã hoàn thành.
GO  -- Separate the batch

CREATE TRIGGER trg_PreventCompletedProjectDeletion
ON DuAn
AFTER DELETE
AS
BEGIN
    -- Check if any of the deleted rows have TrangThai = 'Hoàn thành'
    IF EXISTS (
        SELECT 1
        FROM deleted
        WHERE TrangThai = N'Hoàn thành'
    )
    BEGIN
        -- Raise an error and roll back the transaction
        RAISERROR (N'Cannot delete projects with status "Hoàn thành".', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO


-- 106. Tạo một trigger để tự động cập nhật cấp độ kỹ năng của chuyên gia khi họ tham gia vào một dự án mới.
GO  -- Separate the batch

CREATE TRIGGER trg_UpdateSkillLevelOnNewProject
ON ChuyenGia_DuAn
AFTER INSERT
AS
BEGIN
    -- Update the skill levels of specialists based on new project assignments
    UPDATE ChuyenGia_KyNang
    SET CapDo = CASE 
                   WHEN CapDo < 10 THEN CapDo + 1 -- Increment skill level
                   ELSE 10 -- Cap the skill level at 10
                END
    FROM ChuyenGia_KyNang ck
    INNER JOIN inserted i ON ck.MaChuyenGia = i.MaChuyenGia;
END;
GO


-- 107. Tạo một trigger để ghi log mỗi khi có sự thay đổi cấp độ kỹ năng của chuyên gia.
CREATE TABLE SkillLevelChangeLog (
    LogID INT IDENTITY PRIMARY KEY,       -- Unique log identifier
    MaChuyenGia INT,                      -- Specialist ID
    MaKyNang INT,                         -- Skill ID
    OldCapDo INT,                         -- Previous skill level
    NewCapDo INT,                         -- Updated skill level
    ChangeDate DATETIME DEFAULT GETDATE() -- Timestamp of the change
);
GO
CREATE TRIGGER trg_LogSkillLevelChange
ON ChuyenGia_KyNang
AFTER UPDATE
AS
BEGIN
    -- Insert log entries for changes in CapDo
    INSERT INTO SkillLevelChangeLog (MaChuyenGia, MaKyNang, OldCapDo, NewCapDo)
    SELECT 
        i.MaChuyenGia, 
        i.MaKyNang, 
        d.CapDo AS OldCapDo, 
        i.CapDo AS NewCapDo
    FROM inserted i
    INNER JOIN deleted d ON i.MaChuyenGia = d.MaChuyenGia AND i.MaKyNang = d.MaKyNang
    WHERE i.CapDo <> d.CapDo; -- Only log changes where CapDo is updated
END;
GO


-- 108. Tạo một trigger để đảm bảo rằng ngày kết thúc của dự án luôn lớn hơn ngày bắt đầu.
CREATE TRIGGER trg_ValidateProjectDates_Insert
ON DuAn
INSTEAD OF INSERT
AS
BEGIN
    -- Check for invalid dates
    IF EXISTS (
        SELECT 1 
        FROM inserted
        WHERE NgayKetThuc <= NgayBatDau
    )
    BEGIN
        RAISERROR (N'Ngày kết thúc phải lớn hơn ngày bắt đầu.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    -- Insert the valid records
    INSERT INTO DuAn (MaDuAn, TenDuAn, MaCongTy, NgayBatDau, NgayKetThuc, TrangThai)
    SELECT MaDuAn, TenDuAn, MaCongTy, NgayBatDau, NgayKetThuc, TrangThai
    FROM inserted;
END;
GO
CREATE TRIGGER trg_ValidateProjectDates_Update
ON DuAn
INSTEAD OF UPDATE
AS
BEGIN
    -- Check for invalid dates
    IF EXISTS (
        SELECT 1 
        FROM inserted
        WHERE NgayKetThuc <= NgayBatDau
    )
    BEGIN
        RAISERROR (N'Ngày kết thúc phải lớn hơn ngày bắt đầu.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    -- Update the valid records
    UPDATE DuAn
    SET MaCongTy = i.MaCongTy,
        TenDuAn = i.TenDuAn,
        NgayBatDau = i.NgayBatDau,
        NgayKetThuc = i.NgayKetThuc,
        TrangThai = i.TrangThai
    FROM DuAn d
    INNER JOIN inserted i ON d.MaDuAn = i.MaDuAn;
END;
GO


-- 109. Tạo một trigger để tự động xóa các bản ghi liên quan trong bảng ChuyenGia_KyNang khi một kỹ năng bị xóa.

CREATE TRIGGER trg_DeleteSkillReferences
ON KyNang
AFTER DELETE
AS
BEGIN
    -- Delete related records in ChuyenGia_KyNang
    DELETE FROM ChuyenGia_KyNang
    WHERE MaKyNang IN (SELECT MaKyNang FROM deleted);
END;
GO

-- 110. Tạo một trigger để đảm bảo rằng một công ty không thể có quá 10 dự án đang thực hiện cùng một lúc.
CREATE TRIGGER trg_LimitActiveProjects
ON DuAn
AFTER INSERT, UPDATE
AS
BEGIN
    -- Check for companies exceeding the limit of 10 active projects
    IF EXISTS (
        SELECT MaCongTy
        FROM (
            SELECT MaCongTy, COUNT(*) AS ActiveProjects
            FROM DuAn
            WHERE TrangThai = N'Đang thực hiện'
            GROUP BY MaCongTy
        ) AS ProjectCounts
        WHERE ActiveProjects > 10
    )
    BEGIN
        RAISERROR (N'Một công ty không thể có quá 10 dự án đang thực hiện.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO


-- Câu hỏi và ví dụ về Triggers bổ sung (123-135)

-- 123. Tạo một trigger để tự động cập nhật lương của chuyên gia dựa trên cấp độ kỹ năng và số năm kinh nghiệm.
ALTER TABLE ChuyenGia
ADD Luong DECIMAL(18, 2);
GO

CREATE TRIGGER trg_UpdateSalary
ON ChuyenGia_KyNang
AFTER INSERT, UPDATE
AS
BEGIN
    DECLARE @MaChuyenGia INT;
    DECLARE @CapDo INT;
    DECLARE @NamKinhNghiem INT;
    DECLARE @NewSalary DECIMAL(18, 2);

    -- Loop through each inserted or updated row in ChuyenGia_KyNang
    DECLARE cur CURSOR FOR
    SELECT MaChuyenGia, CapDo
    FROM inserted;

    OPEN cur;
    FETCH NEXT FROM cur INTO @MaChuyenGia, @CapDo;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Get the number of years of experience for the Chuyen gia
        SELECT @NamKinhNghiem = NamKinhNghiem
        FROM ChuyenGia
        WHERE MaChuyenGia = @MaChuyenGia;

        -- Calculate the new salary based on CapDo and NamKinhNghiem
        -- Example salary calculation formula:
        SET @NewSalary = (1000 * @CapDo) + (200 * @NamKinhNghiem);

        -- Update the salary for the Chuyen gia
        UPDATE ChuyenGia
        SET Luong = @NewSalary
        WHERE MaChuyenGia = @MaChuyenGia;

        FETCH NEXT FROM cur INTO @MaChuyenGia, @CapDo;
    END

    CLOSE cur;
    DEALLOCATE cur;
END;
GO

-- 124. Tạo một trigger để tự động gửi thông báo khi một dự án sắp đến hạn (còn 7 ngày).

-- Tạo bảng ThongBao nếu chưa có
CREATE TABLE ThongBao (
    MaThongBao INT IDENTITY(1,1) PRIMARY KEY,
    MaDuAn INT,
    NoiDung NVARCHAR(500),
    NgayThongBao DATETIME,
    FOREIGN KEY (MaDuAn) REFERENCES DuAn(MaDuAn)
);
GO
CREATE TRIGGER trg_NotifyProjectDeadline
ON DuAn
AFTER INSERT, UPDATE
AS
BEGIN
    DECLARE @MaDuAn INT;
    DECLARE @NgayKetThuc DATE;
    DECLARE @NgayThongBao DATETIME;
    DECLARE @NoiDung NVARCHAR(500);

    -- Get the MaDuAn and NgayKetThuc from the inserted row
    SELECT @MaDuAn = MaDuAn, @NgayKetThuc = NgayKetThuc
    FROM inserted;

    -- Check if the project deadline is within 7 days
    IF DATEDIFF(DAY, GETDATE(), @NgayKetThuc) = 7
    BEGIN
        -- Prepare the notification content
        SET @NoiDung = N'Dự án ' + (SELECT TenDuAn FROM DuAn WHERE MaDuAn = @MaDuAn) + 
                       N' sẽ đến hạn vào ' + CONVERT(NVARCHAR, @NgayKetThuc, 103) + N'.';

        -- Set the current date and time for the notification
        SET @NgayThongBao = GETDATE();

        -- Insert the notification into the ThongBao table
        INSERT INTO ThongBao (MaDuAn, NoiDung, NgayThongBao)
        VALUES (@MaDuAn, @NoiDung, @NgayThongBao);
    END
END;
GO


-- 125. Tạo một trigger để ngăn chặn việc xóa hoặc cập nhật thông tin của chuyên gia đang tham gia dự án.
CREATE TRIGGER trg_PreventDeleteUpdateChuyenGia
ON ChuyenGia
AFTER DELETE, UPDATE
AS
BEGIN
    DECLARE @MaChuyenGia INT;
    DECLARE @ProjectCount INT;

    -- Get the MaChuyenGia of the deleted or updated expert
    IF EXISTS (SELECT * FROM deleted)
    BEGIN
        SELECT @MaChuyenGia = MaChuyenGia FROM deleted;
    END
    ELSE IF EXISTS (SELECT * FROM inserted)
    BEGIN
        SELECT @MaChuyenGia = MaChuyenGia FROM inserted;
    END

    -- Check if the expert is involved in any ongoing projects (projects that are not completed)
    SELECT @ProjectCount = COUNT(*)
    FROM ChuyenGia_DuAn
    INNER JOIN DuAn ON ChuyenGia_DuAn.MaDuAn = DuAn.MaDuAn
    WHERE ChuyenGia_DuAn.MaChuyenGia = @MaChuyenGia
    AND DuAn.TrangThai != N'Hoàn thành';

    -- If the expert is involved in any ongoing projects, raise an error to prevent deletion or update
    IF @ProjectCount > 0
    BEGIN
        RAISERROR('Không thể xóa hoặc cập nhật thông tin của chuyên gia đang tham gia vào dự án!', 16, 1);
        ROLLBACK;  -- Rollback the delete or update operation
    END
END;
GO


-- 126. Tạo một trigger để tự động cập nhật số lượng chuyên gia trong mỗi chuyên ngành.
-- Tạo bảng ThongKeChuyenNganh nếu chưa có
CREATE TABLE ChuyenNganh_Count (
    ChuyenNganh NVARCHAR(50) PRIMARY KEY,
    SoLuongChuyenGia INT
);
GO
CREATE TRIGGER trg_UpdateChuyenNganhCount
ON ChuyenGia
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    DECLARE @ChuyenNganh NVARCHAR(50);
    DECLARE @SoLuongChuyenGia INT;

    -- Handle INSERT operations
    IF EXISTS (SELECT * FROM inserted)
    BEGIN
        -- Get the ChuyenNganh from the inserted row
        SELECT @ChuyenNganh = ChuyenNganh FROM inserted;
        
        -- Update the count of specialists in the field
        SELECT @SoLuongChuyenGia = COUNT(*) 
        FROM ChuyenGia
        WHERE ChuyenNganh = @ChuyenNganh;

        -- Insert or update the count in ChuyenNganh_Count table
        IF EXISTS (SELECT * FROM ChuyenNganh_Count WHERE ChuyenNganh = @ChuyenNganh)
        BEGIN
            UPDATE ChuyenNganh_Count
            SET SoLuongChuyenGia = @SoLuongChuyenGia
            WHERE ChuyenNganh = @ChuyenNganh;
        END
        ELSE
        BEGIN
            INSERT INTO ChuyenNganh_Count (ChuyenNganh, SoLuongChuyenGia)
            VALUES (@ChuyenNganh, @SoLuongChuyenGia);
        END
    END

    -- Handle DELETE operations
    IF EXISTS (SELECT * FROM deleted)
    BEGIN
        -- Get the ChuyenNganh from the deleted row
        SELECT @ChuyenNganh = ChuyenNganh FROM deleted;
        
        -- Update the count of specialists in the field
        SELECT @SoLuongChuyenGia = COUNT(*) 
        FROM ChuyenGia
        WHERE ChuyenNganh = @ChuyenNganh;

        -- Update the count in ChuyenNganh_Count table
        IF EXISTS (SELECT * FROM ChuyenNganh_Count WHERE ChuyenNganh = @ChuyenNganh)
        BEGIN
            UPDATE ChuyenNganh_Count
            SET SoLuongChuyenGia = @SoLuongChuyenGia
            WHERE ChuyenNganh = @ChuyenNganh;
        END
    END

    -- Handle UPDATE operations
    IF EXISTS (SELECT * FROM inserted) AND EXISTS (SELECT * FROM deleted)
    BEGIN
        -- Get the ChuyenNganh from the inserted and deleted rows
        DECLARE @OldChuyenNganh NVARCHAR(50);
        DECLARE @NewChuyenNganh NVARCHAR(50);

        SELECT @OldChuyenNganh = ChuyenNganh FROM deleted;
        SELECT @NewChuyenNganh = ChuyenNganh FROM inserted;

        -- Update the count of specialists in the old and new fields
        IF @OldChuyenNganh != @NewChuyenNganh
        BEGIN
            -- For old field
            SELECT @SoLuongChuyenGia = COUNT(*) 
            FROM ChuyenGia
            WHERE ChuyenNganh = @OldChuyenNganh;

            IF EXISTS (SELECT * FROM ChuyenNganh_Count WHERE ChuyenNganh = @OldChuyenNganh)
            BEGIN
                UPDATE ChuyenNganh_Count
                SET SoLuongChuyenGia = @SoLuongChuyenGia
                WHERE ChuyenNganh = @OldChuyenNganh;
            END

            -- For new field
            SELECT @SoLuongChuyenGia = COUNT(*) 
            FROM ChuyenGia
            WHERE ChuyenNganh = @NewChuyenNganh;

            IF EXISTS (SELECT * FROM ChuyenNganh_Count WHERE ChuyenNganh = @NewChuyenNganh)
            BEGIN
                UPDATE ChuyenNganh_Count
                SET SoLuongChuyenGia = @SoLuongChuyenGia
                WHERE ChuyenNganh = @NewChuyenNganh;
            END
            ELSE
            BEGIN
                INSERT INTO ChuyenNganh_Count (ChuyenNganh, SoLuongChuyenGia)
                VALUES (@NewChuyenNganh, @SoLuongChuyenGia);
            END
        END
    END
END;
GO



-- 127. Tạo một trigger để tự động tạo bản sao lưu của dự án khi nó được đánh dấu là hoàn thành.

-- Tạo bảng DuAnHoanThanh nếu chưa có
CREATE TABLE DuAn_Backup (
    MaDuAn INT PRIMARY KEY,
    TenDuAn NVARCHAR(200),
    MaCongTy INT,
    NgayBatDau DATE,
    NgayKetThuc DATE,
    TrangThai NVARCHAR(50),
    NgayBackup DATETIME
);
GO
CREATE TRIGGER trg_BackupDuAn
ON DuAn
AFTER UPDATE
AS
BEGIN
    -- Declare variables to hold the project details
    DECLARE @MaDuAn INT;
    DECLARE @TenDuAn NVARCHAR(200);
    DECLARE @MaCongTy INT;
    DECLARE @NgayBatDau DATE;
    DECLARE @NgayKetThuc DATE;
    DECLARE @TrangThai NVARCHAR(50);
    
    -- Check if the project status is updated to 'Hoàn thành' and if the status changed
    IF EXISTS (SELECT * FROM inserted WHERE TrangThai = N'Hoàn thành')
    BEGIN
        -- Get the project details from the inserted row
        SELECT @MaDuAn = MaDuAn, 
               @TenDuAn = TenDuAn, 
               @MaCongTy = MaCongTy, 
               @NgayBatDau = NgayBatDau, 
               @NgayKetThuc = NgayKetThuc, 
               @TrangThai = TrangThai
        FROM inserted;

        -- Insert the project into the DuAn_Backup table
        INSERT INTO DuAn_Backup (MaDuAn, TenDuAn, MaCongTy, NgayBatDau, NgayKetThuc, TrangThai, NgayBackup)
        VALUES (@MaDuAn, @TenDuAn, @MaCongTy, @NgayBatDau, @NgayKetThuc, @TrangThai, GETDATE());
    END
END;
GO


-- 128. Tạo một trigger để tự động cập nhật điểm đánh giá trung bình của công ty dựa trên điểm đánh giá của các dự án.

ALTER TABLE CongTy
ADD DiemDanhGiaTrungBinh FLOAT;
GO
ALTER TABLE DuAn
ADD DiemDanhGia FLOAT;
GO
CREATE TRIGGER trg_UpdateDiemDanhGiaTrungBinh
ON DuAn
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    DECLARE @MaCongTy INT;

    -- Get the company ID for the affected project(s)
    IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        SELECT @MaCongTy = MaCongTy FROM inserted;
    END
    ELSE IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        SELECT @MaCongTy = MaCongTy FROM deleted;
    END

    -- Calculate the average rating for the company based on the project's ratings
    DECLARE @AverageRating FLOAT;

    SELECT @AverageRating = AVG(DiemDanhGia)
    FROM DuAn
    WHERE MaCongTy = @MaCongTy;

    -- Update the average rating of the company
    UPDATE CongTy
    SET DiemDanhGiaTrungBinh = @AverageRating
    WHERE MaCongTy = @MaCongTy;
END;
GO


-- 129. Tạo một trigger để tự động phân công chuyên gia vào dự án dựa trên kỹ năng và kinh nghiệm.
CREATE TABLE DuAn_KyNang (
    MaDuAn INT,
    MaKyNang INT,
    YeuCauCapDo INT,  -- Minimum level required for the skill
    PRIMARY KEY (MaDuAn, MaKyNang),
    FOREIGN KEY (MaDuAn) REFERENCES DuAn(MaDuAn),
    FOREIGN KEY (MaKyNang) REFERENCES KyNang(MaKyNang)
);
GO
CREATE TRIGGER trg_AutoAssignChuyenGiaToDuAn
ON DuAn_KyNang
AFTER INSERT
AS
BEGIN
    DECLARE @MaDuAn INT, @MaKyNang INT, @YeuCauCapDo INT;

    -- Get the skill requirement for the inserted record
    SELECT @MaDuAn = MaDuAn, @MaKyNang = MaKyNang, @YeuCauCapDo = YeuCauCapDo
    FROM inserted;

    -- Assign experts who have the skill and meet the experience and proficiency level requirements
    INSERT INTO ChuyenGia_DuAn (MaChuyenGia, MaDuAn, VaiTro, NgayThamGia)
    SELECT cg.MaChuyenGia, @MaDuAn, 'Chuyên gia', GETDATE()
    FROM ChuyenGia cg
    JOIN ChuyenGia_KyNang cgn ON cg.MaChuyenGia = cgn.MaChuyenGia
    WHERE cgn.MaKyNang = @MaKyNang  
    AND cgn.CapDo >= @YeuCauCapDo   
    AND cg.NamKinhNghiem >= 5        
    AND NOT EXISTS (                
        SELECT 1
        FROM ChuyenGia_DuAn cgd
        WHERE cgd.MaChuyenGia = cg.MaChuyenGia AND cgd.MaDuAn = @MaDuAn
    );
END;
GO



-- 130. Tạo một trigger để tự động cập nhật trạng thái "bận" của chuyên gia khi họ được phân công vào dự án mới.
ALTER TABLE ChuyenGia
ADD TrangThai NVARCHAR(50);
GO
CREATE TRIGGER trg_UpdateTrangThaiChuyenGia
ON ChuyenGia_DuAn
AFTER INSERT
AS
BEGIN
    DECLARE @MaChuyenGia INT;

   
    SELECT @MaChuyenGia = MaChuyenGia
    FROM inserted;
    UPDATE ChuyenGia
    SET TrangThai = N'Bận'
    WHERE MaChuyenGia = @MaChuyenGia;
END;
GO



-- 131. Tạo một trigger để ngăn chặn việc thêm kỹ năng trùng lặp cho một chuyên gia.
CREATE TRIGGER trg_PreventDuplicateSkills
ON ChuyenGia_KyNang
AFTER INSERT
AS
BEGIN
    DECLARE @MaChuyenGia INT;
    DECLARE @MaKyNang INT;

    -- Get the inserted MaChuyenGia and MaKyNang values
    SELECT @MaChuyenGia = MaChuyenGia, @MaKyNang = MaKyNang
    FROM inserted;

    -- Check if the combination of MaChuyenGia and MaKyNang already exists
    IF EXISTS (SELECT 1 
               FROM ChuyenGia_KyNang
               WHERE MaChuyenGia = @MaChuyenGia
                 AND MaKyNang = @MaKyNang)
    BEGIN
        -- If a duplicate is found, raise an error to prevent the insert
        RAISERROR('Kỹ năng này đã tồn tại cho chuyên gia này.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO



-- 132. Tạo một trigger để tự động tạo báo cáo tổng kết khi một dự án kết thúc.
CREATE TABLE BaoCaoTongKet (
    MaDuAn INT PRIMARY KEY,
    TenDuAn NVARCHAR(200),
    MaCongTy INT,
    NgayBatDau DATE,
    NgayKetThuc DATE,
    SoChuyenGia INT,
    DiemDanhGiaTrungBinh FLOAT
);
GO
CREATE TRIGGER trg_GenerateSummaryReport
ON DuAn
AFTER UPDATE
AS
BEGIN
    DECLARE @MaDuAn INT, @TenDuAn NVARCHAR(200), @MaCongTy INT;
    DECLARE @NgayBatDau DATE, @NgayKetThuc DATE, @SoChuyenGia INT, @DiemDanhGiaTrungBinh FLOAT;

    -- Get the updated values from the inserted table
    SELECT @MaDuAn = MaDuAn, @TenDuAn = TenDuAn, @MaCongTy = MaCongTy,
           @NgayBatDau = NgayBatDau, @NgayKetThuc = NgayKetThuc
    FROM inserted
    WHERE TrangThai = N'Hoàn thành';

    -- Check if the status has been updated to "Hoàn thành"
    IF EXISTS (SELECT 1 FROM inserted WHERE TrangThai = N'Hoàn thành')
    BEGIN
        -- Calculate the number of specialists involved in the project
        SELECT @SoChuyenGia = COUNT(DISTINCT MaChuyenGia)
        FROM ChuyenGia_DuAn
        WHERE MaDuAn = @MaDuAn;

        -- Calculate the average rating for the project
        SELECT @DiemDanhGiaTrungBinh = AVG(DiemDanhGia)
        FROM DuAn
        WHERE MaDuAn = @MaDuAn;

        -- Insert the summary report into the BaoCaoTongKet table
        INSERT INTO BaoCaoTongKet (MaDuAn, TenDuAn, MaCongTy, NgayBatDau, NgayKetThuc, SoChuyenGia, DiemDanhGiaTrungBinh)
        VALUES (@MaDuAn, @TenDuAn, @MaCongTy, @NgayBatDau, @NgayKetThuc, @SoChuyenGia, @DiemDanhGiaTrungBinh);
    END
END;
GO


-- 133. Tạo một trigger để tự động cập nhật thứ hạng của công ty dựa trên số lượng dự án hoàn thành và điểm đánh giá.
ALTER TABLE CongTy
ADD HieuQuaCongTy INT DEFAULT 0; -- Default rank of 0, can later be updated based on projects and ratings.
GO

CREATE TRIGGER trg_UpdateCompanyRank
ON DuAn
AFTER UPDATE
AS
BEGIN
    DECLARE @MaCongTy INT;
    DECLARE @SoDuAnHoanThanh INT, @DiemDanhGiaTrungBinh FLOAT;

    -- Get the MaCongTy from the updated project
    SELECT @MaCongTy = MaCongTy
    FROM inserted
    WHERE TrangThai = N'Hoàn thành'; -- Only update if the status is completed

    -- Check if the status was updated to 'Hoàn thành'
    IF EXISTS (SELECT 1 FROM inserted WHERE TrangThai = N'Hoàn thành')
    BEGIN
        -- Calculate the number of completed projects for the company
        SELECT @SoDuAnHoanThanh = COUNT(*)
        FROM DuAn
        WHERE MaCongTy = @MaCongTy AND TrangThai = N'Hoàn thành';

        -- Calculate the average rating for the completed projects
        SELECT @DiemDanhGiaTrungBinh = AVG(DiemDanhGia)
        FROM DuAn
        WHERE MaCongTy = @MaCongTy AND TrangThai = N'Hoàn thành';

        -- Calculate the company rank based on the number of completed projects and average rating
        DECLARE @HieuQua INT;
        SET @HieuQua = (@SoDuAnHoanThanh * 2) + (COALESCE(@DiemDanhGiaTrungBinh, 0) * 10); -- Ranking formula

        -- Update the company's rank in the CongTy table
        UPDATE CongTy
        SET HieuQuaCongTy = @HieuQua
        WHERE MaCongTy = @MaCongTy;
    END
END;
GO



