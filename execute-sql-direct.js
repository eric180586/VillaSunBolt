const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.VITE_SUPABASE_URL,
  process.env.VITE_SUPABASE_ANON_KEY
);

(async () => {
  const { data, error } = await supabase
    .from('checklists')
    .select('id')
    .limit(1);
    
  if (error) {
    console.log('Checklists table error:', error.message);
  } else {
    console.log('Checklists table exists!');
  }
  
  // Try checklist_instances
  const { data: data2, error: error2 } = await supabase
    .from('checklist_instances')
    .select('id')
    .limit(1);
    
  if (error2) {
    console.log('Checklist_instances table error:', error2.message);
  } else {
    console.log('Checklist_instances table exists!');
  }
})();
