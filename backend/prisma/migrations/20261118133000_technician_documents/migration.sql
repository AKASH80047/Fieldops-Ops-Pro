CREATE TYPE "TechnicianDocumentStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

CREATE TABLE "TechnicianDocument" (
  "id" TEXT NOT NULL,
  "technicianId" TEXT NOT NULL,
  "type" TEXT NOT NULL,
  "objectKey" TEXT NOT NULL,
  "mimeType" TEXT NOT NULL,
  "status" "TechnicianDocumentStatus" NOT NULL DEFAULT 'PENDING',
  "rejectionReason" TEXT,
  "uploadedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "reviewedAt" TIMESTAMP(3),
  "reviewedById" TEXT,
  CONSTRAINT "TechnicianDocument_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "TechnicianDocument_technicianId_status_idx" ON "TechnicianDocument"("technicianId", "status");
ALTER TABLE "TechnicianDocument" ADD CONSTRAINT "TechnicianDocument_technicianId_fkey" FOREIGN KEY ("technicianId") REFERENCES "Technician"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE UNIQUE INDEX "JobAssignment_one_active_per_job_key" ON "JobAssignment"("jobId") WHERE "unassignedAt" IS NULL;
