-- CreateTable
CREATE TABLE "CardBundle" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "gemPrice" INTEGER NOT NULL,
    "artUrl" TEXT,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "dropOpensAt" TIMESTAMP(3),
    "dropClosesAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CardBundle_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CardBundleEntry" (
    "id" TEXT NOT NULL,
    "bundleId" TEXT NOT NULL,
    "templateId" TEXT NOT NULL,

    CONSTRAINT "CardBundleEntry_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "CardBundleEntry_bundleId_idx" ON "CardBundleEntry"("bundleId");

-- CreateIndex
CREATE UNIQUE INDEX "CardBundleEntry_bundleId_templateId_key" ON "CardBundleEntry"("bundleId", "templateId");

-- AddForeignKey
ALTER TABLE "CardBundleEntry" ADD CONSTRAINT "CardBundleEntry_bundleId_fkey" FOREIGN KEY ("bundleId") REFERENCES "CardBundle"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CardBundleEntry" ADD CONSTRAINT "CardBundleEntry_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "CardTemplate"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
