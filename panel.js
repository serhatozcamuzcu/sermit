const SETTINGS_KEY = 'novagenPanelSettings';

const DEFAULT_CHANNELS = [
  { key: 'CIKIS1', label: 'Çıkış 1' },
  { key: 'CIKIS2', label: 'Çıkış 2' },
  { key: 'CIKIS3', label: 'Çıkış 3' },
  { key: 'CIKIS4', label: 'Çıkış 4' },
];

function loadSettings() {
  try {
    const raw = localStorage.getItem(SETTINGS_KEY);
    if (!raw) return { brokerHost: '', deviceId: '', mqttUser: '', channels: DEFAULT_CHANNELS };
    const parsed = JSON.parse(raw);
    return {
      brokerHost: parsed.brokerHost || '',
      deviceId: parsed.deviceId || '',
      mqttUser: parsed.mqttUser || '',
      cmdTopicTpl: parsed.cmdTopicTpl || 'cihaz/{deviceId}/komut',
      statusTopicTpl: parsed.statusTopicTpl || 'cihaz/{deviceId}/durum',
      channels: Array.isArray(parsed.channels) && parsed.channels.length ? parsed.channels : DEFAULT_CHANNELS,
    };
  } catch {
    return { brokerHost: '', deviceId: '', mqttUser: '', channels: DEFAULT_CHANNELS };
  }
}

function saveSettings(settings) {
  try {
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
  } catch {
    /* localStorage may be unavailable (private mode); settings just won't persist */
  }
}

let settings = loadSettings();
let client = null;
let cmdTopic = '';
let statusTopic = '';
let channelStates = {};

const loginView = document.getElementById('loginView');
const dashboardView = document.getElementById('dashboardView');
const loginForm = document.getElementById('loginForm');
const loginError = document.getElementById('loginError');
const connectBtn = document.getElementById('connectBtn');
const brokerHostInput = document.getElementById('brokerHost');
const deviceIdInput = document.getElementById('deviceId');
const mqttUserInput = document.getElementById('mqttUser');
const mqttPassInput = document.getElementById('mqttPass');
const cmdTopicTplInput = document.getElementById('cmdTopicTpl');
const statusTopicTplInput = document.getElementById('statusTopicTpl');
const advancedToggle = document.getElementById('advancedToggle');
const advancedFields = document.getElementById('advancedFields');

const statusDot = document.getElementById('statusDot');
const statusText = document.getElementById('statusText');
const deviceLabel = document.getElementById('deviceLabel');
const lastUpdate = document.getElementById('lastUpdate');
const channelsEl = document.getElementById('channels');
const rawToggle = document.getElementById('rawToggle');
const rawData = document.getElementById('rawData');
const disconnectBtn = document.getElementById('disconnectBtn');

const settingsBtn = document.getElementById('settingsBtn');
const settingsModal = document.getElementById('settingsModal');
const channelSettingsEl = document.getElementById('channelSettings');
const addChannelBtn = document.getElementById('addChannelBtn');
const closeSettingsBtn = document.getElementById('closeSettingsBtn');
const saveSettingsBtn = document.getElementById('saveSettingsBtn');

brokerHostInput.value = settings.brokerHost;
deviceIdInput.value = settings.deviceId;
mqttUserInput.value = settings.mqttUser;
if (settings.cmdTopicTpl) cmdTopicTplInput.value = settings.cmdTopicTpl;
if (settings.statusTopicTpl) statusTopicTplInput.value = settings.statusTopicTpl;

advancedToggle.addEventListener('click', () => {
  advancedFields.classList.toggle('hidden');
});

rawToggle.addEventListener('click', () => {
  rawData.classList.toggle('hidden');
});

function resolveTopic(template, deviceId) {
  return template.replace('{deviceId}', deviceId);
}

function setStatus(state, text) {
  statusDot.className = 'status-dot ' + state;
  statusText.textContent = text;
}

function renderChannels() {
  channelsEl.innerHTML = '';
  settings.channels.forEach((ch) => {
    const row = document.createElement('div');
    row.className = 'channel-row';

    const info = document.createElement('div');
    info.className = 'channel-info';
    const name = document.createElement('span');
    name.className = 'channel-name';
    name.textContent = ch.label;
    const state = document.createElement('span');
    state.className = 'channel-state off';
    state.id = `state-${ch.key}`;
    state.textContent = 'Durum bilinmiyor';
    info.appendChild(name);
    info.appendChild(state);

    const toggle = document.createElement('label');
    toggle.className = 'toggle';
    const input = document.createElement('input');
    input.type = 'checkbox';
    input.id = `toggle-${ch.key}`;
    input.addEventListener('change', () => {
      publishCommand(ch.key, input.checked ? 'AC' : 'KAPA');
    });
    const slider = document.createElement('span');
    slider.className = 'toggle-slider';
    toggle.appendChild(input);
    toggle.appendChild(slider);

    row.appendChild(info);
    row.appendChild(toggle);
    channelsEl.appendChild(row);
  });
}

function publishCommand(channelKey, state) {
  if (!client || !client.connected) return;
  const payload = JSON.stringify({ channel: channelKey, state });
  client.publish(cmdTopic, payload, { qos: 1 });
}

function applyStatusPayload(data) {
  rawData.textContent = JSON.stringify(data, null, 2);
  lastUpdate.textContent = 'Son veri: ' + new Date().toLocaleTimeString('tr-TR');

  settings.channels.forEach((ch) => {
    const val = data[ch.key];
    if (val === undefined) return;
    const isOn = val === true || val === 'AC' || val === 'ON' || val === 1;
    const toggleInput = document.getElementById(`toggle-${ch.key}`);
    const stateLabel = document.getElementById(`state-${ch.key}`);
    if (toggleInput) toggleInput.checked = isOn;
    if (stateLabel) {
      stateLabel.textContent = isOn ? 'Açık' : 'Kapalı';
      stateLabel.className = 'channel-state ' + (isOn ? 'on' : 'off');
    }
  });
}

function connect(brokerHost, deviceId, user, pass, cmdTpl, statusTpl) {
  loginError.classList.add('hidden');
  connectBtn.disabled = true;
  connectBtn.textContent = 'Bağlanıyor…';

  cmdTopic = resolveTopic(cmdTpl, deviceId);
  statusTopic = resolveTopic(statusTpl, deviceId);

  const url = `wss://${brokerHost}:8884/mqtt`;
  client = mqtt.connect(url, {
    username: user,
    password: pass,
    clientId: 'novagen-panel-' + Math.random().toString(16).slice(2, 10),
    clean: true,
    connectTimeout: 10000,
    reconnectPeriod: 4000,
  });

  const connectFailTimer = setTimeout(() => {
    if (!client.connected) {
      showLoginError('Bağlantı zaman aşımına uğradı. Broker adresini ve bilgileri kontrol edin.');
      client.end(true);
    }
  }, 12000);

  client.on('connect', () => {
    clearTimeout(connectFailTimer);
    settings.brokerHost = brokerHost;
    settings.deviceId = deviceId;
    settings.mqttUser = user;
    settings.cmdTopicTpl = cmdTpl;
    settings.statusTopicTpl = statusTpl;
    saveSettings(settings);

    client.subscribe(statusTopic, { qos: 1 });

    deviceLabel.textContent = `Cihaz: ${deviceId}`;
    loginView.classList.add('hidden');
    dashboardView.classList.remove('hidden');
    renderChannels();
    setStatus('online', 'Bağlı');
    connectBtn.disabled = false;
    connectBtn.textContent = 'Bağlan';
  });

  client.on('reconnect', () => setStatus('offline', 'Yeniden bağlanıyor…'));
  client.on('close', () => setStatus('offline', 'Bağlantı yok'));
  client.on('error', (err) => {
    clearTimeout(connectFailTimer);
    setStatus('error', 'Bağlantı hatası');
    if (!dashboardView.classList.contains('hidden')) return;
    showLoginError('Bağlanılamadı: kullanıcı adı, şifre veya broker adresini kontrol edin.');
    connectBtn.disabled = false;
    connectBtn.textContent = 'Bağlan';
  });

  client.on('message', (topic, message) => {
    if (topic !== statusTopic) return;
    try {
      applyStatusPayload(JSON.parse(message.toString()));
    } catch {
      rawData.textContent = message.toString();
      lastUpdate.textContent = 'Son veri: ' + new Date().toLocaleTimeString('tr-TR');
    }
  });
}

function showLoginError(msg) {
  loginError.textContent = msg;
  loginError.classList.remove('hidden');
}

loginForm.addEventListener('submit', (e) => {
  e.preventDefault();
  connect(
    brokerHostInput.value.trim(),
    deviceIdInput.value.trim(),
    mqttUserInput.value,
    mqttPassInput.value,
    cmdTopicTplInput.value.trim() || 'cihaz/{deviceId}/komut',
    statusTopicTplInput.value.trim() || 'cihaz/{deviceId}/durum'
  );
});

disconnectBtn.addEventListener('click', () => {
  if (client) client.end(true);
  mqttPassInput.value = '';
  dashboardView.classList.add('hidden');
  loginView.classList.remove('hidden');
  setStatus('offline', 'Bağlanıyor…');
});

// Settings modal — channel labels/keys
function openSettingsModal() {
  channelSettingsEl.innerHTML = '';
  settings.channels.forEach((ch, i) => addChannelSettingRow(ch.label, ch.key, i));
  settingsModal.classList.remove('hidden');
}

function addChannelSettingRow(label = '', key = '', index) {
  const row = document.createElement('div');
  row.className = 'channel-setting-row';

  const labelInput = document.createElement('input');
  labelInput.placeholder = 'Etiket (ör. Motor)';
  labelInput.value = label;
  labelInput.dataset.field = 'label';

  const keyInput = document.createElement('input');
  keyInput.placeholder = 'MQTT anahtarı (ör. CIKIS1)';
  keyInput.value = key;
  keyInput.dataset.field = 'key';

  const removeBtn = document.createElement('button');
  removeBtn.type = 'button';
  removeBtn.textContent = '✕';
  removeBtn.addEventListener('click', () => row.remove());

  row.appendChild(labelInput);
  row.appendChild(keyInput);
  row.appendChild(removeBtn);
  channelSettingsEl.appendChild(row);
}

settingsBtn.addEventListener('click', openSettingsModal);
closeSettingsBtn.addEventListener('click', () => settingsModal.classList.add('hidden'));
addChannelBtn.addEventListener('click', () => addChannelSettingRow());

saveSettingsBtn.addEventListener('click', () => {
  const rows = channelSettingsEl.querySelectorAll('.channel-setting-row');
  const newChannels = [];
  rows.forEach((row) => {
    const label = row.querySelector('[data-field="label"]').value.trim();
    const key = row.querySelector('[data-field="key"]').value.trim();
    if (label && key) newChannels.push({ label, key });
  });
  if (newChannels.length) {
    settings.channels = newChannels;
    saveSettings(settings);
    renderChannels();
  }
  settingsModal.classList.add('hidden');
});
