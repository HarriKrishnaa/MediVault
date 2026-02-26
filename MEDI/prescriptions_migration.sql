-- Add vault_id to prescriptions table
ALTER TABLE prescriptions 
ADD COLUMN vault_id UUID REFERENCES family_vaults(id);

-- Optional: Add index for faster queries by vault
CREATE INDEX idx_prescriptions_vault_id ON prescriptions(vault_id);

-- (Optional) If you want to enforce one-vault-per-person semantics in the vaults table more clearly:
-- ALTER TABLE family_vaults RENAME COLUMN vault_name TO member_name;
-- ALTER TABLE family_vaults ADD COLUMN member_relation TEXT; 
-- But for now, we will use 'vault_name' as Member Name and 'description' as Relation if available.
