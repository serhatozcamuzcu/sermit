const SETTINGS_KEY = 'novagenPanelSettings';

const DEFAULTS = {
  brokerHost: '',
  deviceId: '',
  mqttUser: '',
  cmdTopicTpl: 'cihaz/{deviceId}/komut',
  statusTopicTpl: 'cihaz/{deviceId}/durum',
};

// İnovance AC sürücü hata kodları (kılavuz s.65-66, register 8000 - "AC drive fault description")
const FAULT_CODES = {
  '0000': 'Hata yok',
  '0001': 'Rezerve',
  '0002': 'Hızlanırken aşırı akım',
  '0003': 'Yavaşlarken aşırı akım',
  '0004': 'Sabit hızda aşırı akım',
  '0005': 'Hızlanırken aşırı gerilim',
  '0006': 'Yavaşlarken aşırı gerilim',
  '0007': 'Sabit hızda aşırı gerilim',
  '0008': 'Ön şarj direnci aşırı yüklenmesi',
  '0009': 'Düşük gerilim (undervoltage)',
  '000A': 'Sürücü aşırı yüklenmesi',
  '000B': 'Motor aşırı yüklenmesi',
  '000C': 'Giriş faz kaybı',
  '000D': 'Çıkış faz kaybı',
  '000E': 'IGBT aşırı ısınma',
  '000F': 'Harici hata',
  '0010': 'Haberleşme hatası (anormal)',
  '0012': 'Akım algılama hatası',
  '0013': 'Motor oto ayar (auto-tuning) hatası',
  '0015': 'Parametre okuma/yazma hatası',
  '0017': 'Motor gövdeye kısa devre',
  '001A': 'Çalışma süresi doldu',
  '001B': 'Kullanıcı tanımlı hata 1',
  '001C': 'Kullanıcı tanımlı hata 2',
  '001D': 'Açık kalma süresi doldu',
  '001E': 'Yük kaybı',
  '001F': 'PID geri besleme kaybı (çalışırken)',
  '0028': 'Hızlı akım sınırlama zaman aşımı',
  '0037': 'Hız senkronizasyonunda slave hatası',
};

function faultDescription(code) {
  const key = String(code).toUpperCase().padStart(4, '0');
  return FAULT_CODES[key] || `Bilinmeyen hata kodu (${key})`;
}

function loadSettings() {
  try {
    const raw = localStorage.getItem(SETTINGS_KEY);
    if (!raw) return { ...DEFAULTS };
    const parsed = JSON.parse(raw);
    return {
      brokerHost: parsed.brokerHost || '',
      deviceId: parsed.deviceId || '',
      mqttUser: parsed.mqttUser || '',
      cmdTopicTpl: parsed.cmdTopicTpl || DEFAULTS.cmdTopicTpl,
      statusTopicTpl: parsed.statusTopicTpl || DEFAULTS.statusTopicTpl,
    };
  } catch {
    return { ...DEFAULTS };
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
const rawToggle = document.getElementById('rawToggle');
const rawData = document.getElementById('rawData');
const disconnectBtn = document.getElementById('disconnectBtn');

const faultBanner = document.getElementById('faultBanner');
const faultTitle = document.getElementById('faultTitle');
const faultDesc = document.getElementById('faultDesc');
const driveStateDot = document.getElementById('driveStateDot');
const driveStateText = document.getElementById('driveStateText');

const startBtn = document.getElementById('startBtn');
const reverseBtn = document.getElementById('reverseBtn');
const stopBtn = document.getElementById('stopBtn');
const resetFaultBtn = document.getElementById('resetFaultBtn');

const teleFreq = document.getElementById('teleFreq');
const teleCurrent = document.getElementById('teleCurrent');
const teleVoltage = document.getElementById('teleVoltage');
const teleSpeed = document.getElementById('teleSpeed');

if (settings.brokerHost) brokerHostInput.value = settings.brokerHost;
if (settings.deviceId) deviceIdInput.value = settings.deviceId;
if (settings.mqttUser) mqttUserInput.value = settings.mqttUser;
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

function publishCommand(cmd) {
  if (!client || !client.connected) return;
  client.publish(cmdTopic, JSON.stringify({ cmd }), { qos: 1 });
}

startBtn.addEventListener('click', () => {
  if (confirm('Sürücüyü ileri yönde çalıştırmak istediğinize emin misiniz?')) {
    publishCommand('START');
  }
});
reverseBtn.addEventListener('click', () => {
  if (confirm('Sürücüyü ters yönde çalıştırmak istediğinize emin misiniz?')) {
    publishCommand('REVERSE');
  }
});
stopBtn.addEventListener('click', () => publishCommand('STOP'));
resetFaultBtn.addEventListener('click', () => publishCommand('FAULT_RESET'));

// Beklenen durum (status) JSON alanları — ESP32 firmware bunları yayınlamalı:
// { "state": "FORWARD"|"REVERSE"|"STOPPED", "fault_code": "0000",
//   "freq_hz": 42.5, "current_a": 3.2, "voltage_v": 380, "speed_rpm": 1450 }
// Değerler ESP32 tarafında register ölçek katsayılarıyla (örn. frekans /100) çevrilmiş olarak gönderilmelidir.
function applyStatusPayload(data) {
  rawData.textContent = JSON.stringify(data, null, 2);
  lastUpdate.textContent = 'Son veri: ' + new Date().toLocaleTimeString('tr-TR');

  const state = data.state;
  if (state === 'FORWARD') {
    driveStateDot.className = 'drive-state-dot running';
    driveStateText.textContent = 'Çalışıyor (İleri)';
  } else if (state === 'REVERSE') {
    driveStateDot.className = 'drive-state-dot running';
    driveStateText.textContent = 'Çalışıyor (Geri)';
  } else if (state === 'STOPPED') {
    driveStateDot.className = 'drive-state-dot stopped';
    driveStateText.textContent = 'Durdu';
  } else {
    driveStateDot.className = 'drive-state-dot';
    driveStateText.textContent = 'Durum bilinmiyor';
  }

  const faultCode = data.fault_code;
  if (faultCode !== undefined && faultCode !== null && String(faultCode).toUpperCase() !== '0000') {
    faultTitle.textContent = `Hata (${String(faultCode).toUpperCase()})`;
    faultDesc.textContent = faultDescription(faultCode);
    faultBanner.classList.remove('hidden');
  } else {
    faultBanner.classList.add('hidden');
  }

  teleFreq.textContent = data.freq_hz !== undefined ? `${data.freq_hz} Hz` : '—';
  teleCurrent.textContent = data.current_a !== undefined ? `${data.current_a} A` : '—';
  teleVoltage.textContent = data.voltage_v !== undefined ? `${data.voltage_v} V` : '—';
  teleSpeed.textContent = data.speed_rpm !== undefined ? `${data.speed_rpm} RPM` : '—';
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
    cmdTopicTplInput.value.trim() || DEFAULTS.cmdTopicTpl,
    statusTopicTplInput.value.trim() || DEFAULTS.statusTopicTpl
  );
});

disconnectBtn.addEventListener('click', () => {
  if (client) client.end(true);
  mqttPassInput.value = '';
  dashboardView.classList.add('hidden');
  loginView.classList.remove('hidden');
  setStatus('offline', 'Bağlanıyor…');
});
