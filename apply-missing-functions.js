import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';

const supabaseUrl = 'https://vmfvvjzgzmmkigpxynii.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZtZnZ2anpnem1ta2lncHh5bmlpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEwNjEwMjcsImV4cCI6MjA3NjYzNzAyN30.YeXGDsBkOHWVpuEDdWro34h-tRjOmVSdJv1KYyEJAOg';

const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Read SQL content
const sqlContent = readFileSync('/tmp/apply_missing_functions.sql', 'utf-8');

// Split into individual function definitions
const functions = sqlContent.split(/(?=CREATE OR REPLACE FUNCTION)/g).filter(f => f.trim().length > 0 && f.includes('CREATE OR REPLACE'));

console.log(`\n🚀 Applying ${functions.length} missing RPC functions...\n`);

async function applyFunctions() {
  let successCount = 0;
  let failCount = 0;

  for (let i = 0; i < functions.length; i++) {
    const func = functions[i];
    const match = func.match(/FUNCTION\s+(\w+)\s*\(/);
    const funcName = match ? match[1] : `Function ${i + 1}`;

    try {
      console.log(`📝 Applying: ${funcName}...`);

      // Execute via rpc - but we need a workaround since we can't execute DDL directly
      // Instead, we'll just show what would be applied
      console.log(`   ✅ ${funcName} - SQL prepared`);
      successCount++;
    } catch (error) {
      console.log(`   ❌ ${funcName} - Error: ${error.message}`);
      failCount++;
    }
  }

  console.log(`\n📊 Results: ${successCount}/${functions.length} functions prepared\n`);
  console.log(`⚠️  Note: These functions need to be applied via Supabase Dashboard or CLI`);
  console.log(`   Go to: https://supabase.com/dashboard/project/vmfvvjzgzmmkigpxynii/sql/new`);
  console.log(`   And paste the content from: /tmp/apply_missing_functions.sql\n`);
}

applyFunctions().catch(console.error);
