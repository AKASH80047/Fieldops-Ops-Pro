CREATE TYPE "TechnicianVerificationStatus" AS ENUM ('DRAFT', 'PENDING_VERIFICATION', 'UNDER_REVIEW', 'APPROVED', 'REJECTED', 'SUSPENDED', 'INACTIVE');
CREATE TYPE "LedgerStatus" AS ENUM ('PENDING', 'AVAILABLE', 'PAID', 'HELD', 'REVERSED');
CREATE TYPE "PayoutStatus" AS ENUM ('REQUESTED', 'APPROVED', 'PROCESSING', 'PAID', 'FAILED', 'REJECTED');

ALTER TABLE "Business" ADD COLUMN "commissionRate" DECIMAL(65,30) NOT NULL DEFAULT 20;
ALTER TABLE "Technician" ADD COLUMN "verificationStatus" "TechnicianVerificationStatus" NOT NULL DEFAULT 'DRAFT';

CREATE TABLE "TechnicianLedger" (
  "id" TEXT NOT NULL,
  "businessId" TEXT NOT NULL,
  "technicianId" TEXT NOT NULL,
  "jobId" TEXT NOT NULL,
  "grossAmount" DECIMAL(65,30) NOT NULL,
  "commissionAmount" DECIMAL(65,30) NOT NULL,
  "netAmount" DECIMAL(65,30) NOT NULL,
  "status" "LedgerStatus" NOT NULL DEFAULT 'PENDING',
  "availableAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "TechnicianLedger_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "TechnicianLedger_jobId_key" ON "TechnicianLedger"("jobId");
CREATE INDEX "TechnicianLedger_businessId_technicianId_status_idx" ON "TechnicianLedger"("businessId", "technicianId", "status");
ALTER TABLE "TechnicianLedger" ADD CONSTRAINT "TechnicianLedger_technicianId_fkey" FOREIGN KEY ("technicianId") REFERENCES "Technician"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "PayoutRequest" (
  "id" TEXT NOT NULL,
  "technicianId" TEXT NOT NULL,
  "amount" DECIMAL(65,30) NOT NULL,
  "status" "PayoutStatus" NOT NULL DEFAULT 'REQUESTED',
  "reference" TEXT,
  "requestedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "processedAt" TIMESTAMP(3),
  CONSTRAINT "PayoutRequest_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "PayoutRequest_technicianId_status_idx" ON "PayoutRequest"("technicianId", "status");
ALTER TABLE "PayoutRequest" ADD CONSTRAINT "PayoutRequest_technicianId_fkey" FOREIGN KEY ("technicianId") REFERENCES "Technician"("id") ON DELETE CASCADE ON UPDATE CASCADE;
