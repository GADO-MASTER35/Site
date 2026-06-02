/* =====================================================================
   CONFIGURACAO DO SUPABASE  (preencha UMA vez — vale para o site e o painel)
   ---------------------------------------------------------------------
   1) Crie um projeto gratis em https://supabase.com
   2) Va em Project Settings > Data API (ou API):
        - "Project URL"  -> cole em SUPABASE_URL
        - "anon public"  -> cole em SUPABASE_ANON_KEY
   3) Salve este arquivo. Os dois arquivos (vitrine e painel) ja usam ele.
   ===================================================================== */

const SUPABASE_URL = "COLE_AQUI_SUA_SUPABASE_URL";
const SUPABASE_ANON_KEY = "COLE_AQUI_SUA_SUPABASE_ANON_KEY";

// E-mail do administrador (unico que entra no painel).
// Tem que ser O MESMO e-mail definido no supabase-setup.sql (funcao is_admin).
const ADMIN_EMAIL = "marcoguilundo@gmail.com";

// Cria o cliente do Supabase (so se a URL ja foi preenchida).
const sb = (typeof supabase !== "undefined" && SUPABASE_URL.startsWith("http"))
  ? supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
  : null;
