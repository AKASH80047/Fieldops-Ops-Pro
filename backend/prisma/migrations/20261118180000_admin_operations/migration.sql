CREATE TYPE "PaymentMethod" AS ENUM ('ONLINE', 'CASH');
CREATE TYPE "RefundStatus" AS ENUM ('REQUESTED', 'APPROVED', 'PROCESSING', 'SUCCEEDED', 'FAILED', 'REJECTED');
CREATE TYPE "CashCollectionStatus" AS ENUM ('SUBMITTED', 'VERIFIED', 'REJECTED');
CREATE TYPE "SupportTicketStatus" AS ENUM ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'REOPENED');
CREATE TYPE "SupportTicketPriority" AS ENUM ('LOW', 'NORMAL', 'HIGH', 'URGENT');

ALTER TABLE "ServiceCategory"
  ADD COLUMN "description" TEXT,
  ADD COLUMN "imageObjectKey" TEXT,
  ADD COLUMN "displayOrder" INTEGER NOT NULL DEFAULT 0;

DROP INDEX IF EXISTS "ServiceCategory_businessId_name_key";
CREATE UNIQUE INDEX "ServiceCategory_businessId_name_active_key"
  ON "ServiceCategory" ("businessId", LOWER("name"))
  WHERE "deletedAt" IS NULL;
CREATE INDEX "ServiceCategory_businessId_active_displayOrder_idx"
  ON "ServiceCategory" ("businessId", "active", "displayOrder");

ALTER TABLE "Service"
  ADD COLUMN "imageObjectKey" TEXT,
  ADD COLUMN "requiredSkills" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];
CREATE UNIQUE INDEX "Service_businessId_categoryId_name_active_key"
  ON "Service" ("businessId", "categoryId", LOWER("name"))
  WHERE "deletedAt" IS NULL;

CREATE UNIQUE INDEX "TechnicianDocument_technicianId_type_key"
  ON "TechnicianDocument"("technicianId", "type");

ALTER TABLE "Payment"
  ADD COLUMN "method" "PaymentMethod" NOT NULL DEFAULT 'ONLINE',
  ADD COLUMN "currency" TEXT NOT NULL DEFAULT 'INR',
  ADD COLUMN "failureReason" TEXT,
  ADD COLUMN "updatedAt" TIMESTAMP(3);
UPDATE "Payment" SET "updatedAt" = "createdAt" WHERE "updatedAt" IS NULL;
ALTER TABLE "Payment" ALTER COLUMN "updatedAt" SET NOT NULL;

ALTER TABLE "Refund" ADD COLUMN "idempotencyKey" TEXT;
UPDATE "Refund" SET "idempotencyKey" = 'legacy:' || "id" WHERE "idempotencyKey" IS NULL;
ALTER TABLE "Refund"
  ALTER COLUMN "idempotencyKey" SET NOT NULL,
  ADD COLUMN "failureReason" TEXT,
  ADD COLUMN "reviewedById" TEXT,
  ADD COLUMN "processedAt" TIMESTAMP(3),
  ADD COLUMN "updatedAt" TIMESTAMP(3);
UPDATE "Refund" SET "updatedAt" = "createdAt" WHERE "updatedAt" IS NULL;
ALTER TABLE "Refund" ALTER COLUMN "updatedAt" SET NOT NULL;
ALTER TABLE "Refund" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "Refund" ALTER COLUMN "status" TYPE "RefundStatus"
  USING (
    CASE UPPER("status")
      WHEN 'APPROVED' THEN 'APPROVED'
      WHEN 'PROCESSING' THEN 'PROCESSING'
      WHEN 'SUCCEEDED' THEN 'SUCCEEDED'
      WHEN 'SUCCESS' THEN 'SUCCEEDED'
      WHEN 'REFUNDED' THEN 'SUCCEEDED'
      WHEN 'FAILED' THEN 'FAILED'
      WHEN 'REJECTED' THEN 'REJECTED'
      ELSE 'REQUESTED'
    END
  )::"RefundStatus";
ALTER TABLE "Refund" ALTER COLUMN "status" SET DEFAULT 'REQUESTED';
CREATE UNIQUE INDEX "Refund_idempotencyKey_key" ON "Refund"("idempotencyKey");
CREATE INDEX "Refund_paymentId_status_idx" ON "Refund"("paymentId", "status");

ALTER TABLE "PayoutRequest"
  ADD COLUMN "businessId" TEXT,
  ADD COLUMN "requestedById" TEXT,
  ADD COLUMN "approvedById" TEXT,
  ADD COLUMN "processedById" TEXT,
  ADD COLUMN "failureReason" TEXT,
  ADD COLUMN "idempotencyKey" TEXT,
  ADD COLUMN "approvedAt" TIMESTAMP(3),
  ADD COLUMN "updatedAt" TIMESTAMP(3);
UPDATE "PayoutRequest" AS payout
SET "businessId" = technician."businessId",
    "updatedAt" = COALESCE(payout."processedAt", payout."requestedAt")
FROM "Technician" AS technician
WHERE payout."technicianId" = technician."id";
ALTER TABLE "PayoutRequest"
  ALTER COLUMN "businessId" SET NOT NULL,
  ALTER COLUMN "updatedAt" SET NOT NULL;
CREATE UNIQUE INDEX "PayoutRequest_idempotencyKey_key" ON "PayoutRequest"("idempotencyKey");
CREATE INDEX "PayoutRequest_businessId_status_requestedAt_idx"
  ON "PayoutRequest"("businessId", "status", "requestedAt");
ALTER TABLE "PayoutRequest" ADD CONSTRAINT "PayoutRequest_businessId_fkey"
  FOREIGN KEY ("businessId") REFERENCES "Business"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "SupportTicket"
  ADD COLUMN "businessId" TEXT,
  ADD COLUMN "bookingId" TEXT,
  ADD COLUMN "jobId" TEXT,
  ADD COLUMN "technicianId" TEXT,
  ADD COLUMN "priority" "SupportTicketPriority" NOT NULL DEFAULT 'NORMAL',
  ADD COLUMN "assignedToId" TEXT,
  ADD COLUMN "adminNotes" TEXT,
  ADD COLUMN "resolution" TEXT,
  ADD COLUMN "resolvedAt" TIMESTAMP(3),
  ADD COLUMN "reopenedAt" TIMESTAMP(3);
UPDATE "SupportTicket" AS ticket
SET "businessId" = customer."businessId"
FROM "Customer" AS customer
WHERE ticket."customerId" = customer."id";
ALTER TABLE "SupportTicket" ALTER COLUMN "businessId" SET NOT NULL;
ALTER TABLE "SupportTicket" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "SupportTicket" ALTER COLUMN "status" TYPE "SupportTicketStatus"
  USING (
    CASE UPPER("status")
      WHEN 'IN_PROGRESS' THEN 'IN_PROGRESS'
      WHEN 'RESOLVED' THEN 'RESOLVED'
      WHEN 'REOPENED' THEN 'REOPENED'
      ELSE 'OPEN'
    END
  )::"SupportTicketStatus";
ALTER TABLE "SupportTicket" ALTER COLUMN "status" SET DEFAULT 'OPEN';
CREATE INDEX "SupportTicket_businessId_status_priority_createdAt_idx"
  ON "SupportTicket"("businessId", "status", "priority", "createdAt");
CREATE INDEX "SupportTicket_bookingId_idx" ON "SupportTicket"("bookingId");
ALTER TABLE "SupportTicket" ADD CONSTRAINT "SupportTicket_businessId_fkey"
  FOREIGN KEY ("businessId") REFERENCES "Business"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "SupportTicket" ADD CONSTRAINT "SupportTicket_bookingId_fkey"
  FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "SupportTicket" ADD CONSTRAINT "SupportTicket_jobId_fkey"
  FOREIGN KEY ("jobId") REFERENCES "Job"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "SupportTicket" ADD CONSTRAINT "SupportTicket_technicianId_fkey"
  FOREIGN KEY ("technicianId") REFERENCES "Technician"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "CashCollection" (
  "id" TEXT NOT NULL,
  "paymentId" TEXT NOT NULL,
  "technicianId" TEXT NOT NULL,
  "receiptObjectKey" TEXT NOT NULL,
  "amount" DECIMAL(65,30) NOT NULL,
  "status" "CashCollectionStatus" NOT NULL DEFAULT 'SUBMITTED',
  "collectedAt" TIMESTAMP(3) NOT NULL,
  "submittedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "verifiedAt" TIMESTAMP(3),
  "verifiedById" TEXT,
  "rejectionReason" TEXT,
  CONSTRAINT "CashCollection_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "CashCollection_paymentId_key" ON "CashCollection"("paymentId");
CREATE INDEX "CashCollection_technicianId_status_submittedAt_idx"
  ON "CashCollection"("technicianId", "status", "submittedAt");
ALTER TABLE "CashCollection" ADD CONSTRAINT "CashCollection_paymentId_fkey"
  FOREIGN KEY ("paymentId") REFERENCES "Payment"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "CashCollection" ADD CONSTRAINT "CashCollection_technicianId_fkey"
  FOREIGN KEY ("technicianId") REFERENCES "Technician"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "ServiceAreaAssignment" (
  "serviceId" TEXT NOT NULL,
  "serviceAreaId" TEXT NOT NULL,
  "active" BOOLEAN NOT NULL DEFAULT true,
  CONSTRAINT "ServiceAreaAssignment_pkey" PRIMARY KEY ("serviceId", "serviceAreaId")
);
CREATE INDEX "ServiceAreaAssignment_serviceAreaId_active_idx"
  ON "ServiceAreaAssignment"("serviceAreaId", "active");
ALTER TABLE "ServiceAreaAssignment" ADD CONSTRAINT "ServiceAreaAssignment_serviceId_fkey"
  FOREIGN KEY ("serviceId") REFERENCES "Service"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ServiceAreaAssignment" ADD CONSTRAINT "ServiceAreaAssignment_serviceAreaId_fkey"
  FOREIGN KEY ("serviceAreaId") REFERENCES "ServiceArea"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "TechnicianServiceArea" (
  "technicianId" TEXT NOT NULL,
  "serviceAreaId" TEXT NOT NULL,
  "active" BOOLEAN NOT NULL DEFAULT true,
  CONSTRAINT "TechnicianServiceArea_pkey" PRIMARY KEY ("technicianId", "serviceAreaId")
);
CREATE INDEX "TechnicianServiceArea_serviceAreaId_active_idx"
  ON "TechnicianServiceArea"("serviceAreaId", "active");
ALTER TABLE "TechnicianServiceArea" ADD CONSTRAINT "TechnicianServiceArea_technicianId_fkey"
  FOREIGN KEY ("technicianId") REFERENCES "Technician"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "TechnicianServiceArea" ADD CONSTRAINT "TechnicianServiceArea_serviceAreaId_fkey"
  FOREIGN KEY ("serviceAreaId") REFERENCES "ServiceArea"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "PayoutLedgerAllocation" (
  "payoutRequestId" TEXT NOT NULL,
  "ledgerId" TEXT NOT NULL,
  "amount" DECIMAL(65,30) NOT NULL,
  "releasedAt" TIMESTAMP(3),
  CONSTRAINT "PayoutLedgerAllocation_pkey" PRIMARY KEY ("payoutRequestId", "ledgerId")
);
CREATE UNIQUE INDEX "PayoutLedgerAllocation_active_ledger_key"
  ON "PayoutLedgerAllocation"("ledgerId") WHERE "releasedAt" IS NULL;
CREATE INDEX "PayoutLedgerAllocation_ledgerId_releasedAt_idx"
  ON "PayoutLedgerAllocation"("ledgerId", "releasedAt");
ALTER TABLE "PayoutLedgerAllocation" ADD CONSTRAINT "PayoutLedgerAllocation_payoutRequestId_fkey"
  FOREIGN KEY ("payoutRequestId") REFERENCES "PayoutRequest"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "PayoutLedgerAllocation" ADD CONSTRAINT "PayoutLedgerAllocation_ledgerId_fkey"
  FOREIGN KEY ("ledgerId") REFERENCES "TechnicianLedger"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
