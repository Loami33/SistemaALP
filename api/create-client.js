const { createClient } = require('@supabase/supabase-js');

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const supabaseAdmin = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

  const token = (req.headers.authorization || '').replace('Bearer ', '');
  const { data: { user }, error: userErr } = await supabaseAdmin.auth.getUser(token);
  if (userErr || !user) return res.status(401).json({ error: 'Não autenticado' });

  const { data: caller } = await supabaseAdmin.from('profiles').select('is_owner').eq('id', user.id).single();
  if (!caller || !caller.is_owner) return res.status(403).json({ error: 'Apenas o dono pode criar clientes' });

  const {
    businessName, ownerName, slug, username, password,
    contactPhone, contactWhatsapp, contactInstagram, city
  } = req.body || {};

  if (!businessName || !slug || !username || !password) {
    return res.status(400).json({ error: 'Campos obrigatórios faltando' });
  }

  const { data: existing } = await supabaseAdmin.from('clients').select('id').eq('slug', slug).maybeSingle();
  if (existing) return res.status(409).json({ error: 'Slug já em uso' });

  const internalEmail = `${username.toLowerCase()}@${slug}.login.sistemaalp.internal`;
  let newAuthUser, newClient;

  try {
    const { data: authData, error: authErr } = await supabaseAdmin.auth.admin.createUser({
      email: internalEmail, password, email_confirm: true
    });
    if (authErr) throw authErr;
    newAuthUser = authData.user;

    const { data: clientRow, error: clientErr } = await supabaseAdmin
      .from('clients')
      .insert({
        slug, business_name: businessName, owner_name: ownerName,
        contact_phone: contactPhone, contact_whatsapp: contactWhatsapp,
        contact_instagram: contactInstagram, city
      })
      .select().single();
    if (clientErr) throw clientErr;
    newClient = clientRow;

    const { error: profileErr } = await supabaseAdmin.from('profiles').insert({
      id: newAuthUser.id, client_id: newClient.id, is_owner: false, username, display_name: ownerName
    });
    if (profileErr) throw profileErr;

    await supabaseAdmin.from('about_sections').insert({ client_id: newClient.id, name: ownerName || '', bio: '', chips: [] });
    await supabaseAdmin.from('theme_settings').insert({ client_id: newClient.id });

    return res.status(201).json({ client: newClient, credentials: { username, password } });
  } catch (err) {
    if (newClient && newClient.id) await supabaseAdmin.from('clients').delete().eq('id', newClient.id);
    if (newAuthUser && newAuthUser.id) await supabaseAdmin.auth.admin.deleteUser(newAuthUser.id);
    return res.status(500).json({ error: 'Falha ao criar cliente', detail: err.message });
  }
};
