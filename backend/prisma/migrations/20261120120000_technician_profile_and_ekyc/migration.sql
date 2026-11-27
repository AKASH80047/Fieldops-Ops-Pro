ALTER TABLE "Technician"
  ADD COLUMN "addressLine1" TEXT,
  ADD COLUMN "addressLine2" TEXT,
  ADD COLUMN "city" TEXT,
  ADD COLUMN "state" TEXT,
  ADD COLUMN "postalCode" TEXT,
  ADD COLUMN "aadhaarLast4" TEXT,
  ADD COLUMN "aadhaarHash" TEXT,
  ADD COLUMN "aadhaarConsentAt" TIMESTAMP(3),
  ADD COLUMN "profileCompletedAt" TIMESTAMP(3);

CREATE UNIQUE INDEX "Technician_aadhaarHash_key" ON "Technician"("aadhaarHash");

ALTER TABLE "Technician"
  ADD CONSTRAINT "Technician_aadhaarLast4_format"
  CHECK ("aadhaarLast4" IS NULL OR "aadhaarLast4" ~ '^[0-9]{4}$');
