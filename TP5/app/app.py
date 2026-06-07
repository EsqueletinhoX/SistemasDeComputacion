from flask import Flask, jsonify, request
import threading, time

DEV = "/dev/SdeC_drv5"
VREF = 3.3
ADC_MAX = 4095
NAMES = {0: "Diente de sierra", 1: "Onda cuadrada"}

app = Flask(__name__)
lock = threading.Lock()
samples = []
channel = 0
t0 = time.time()

def raw_to_volts(raw):
    return raw * VREF / ADC_MAX        # correccion de escala en userspace

def reader():
    while True:
        try:
            with open(DEV, "r") as f:
                raw = int(f.read().strip())
            v = raw_to_volts(raw)
            with lock:
                t = time.time() - t0
                samples.append((round(t, 1), round(v, 3)))
                if len(samples) > 60:
                    samples.pop(0)
        except Exception as e:
            print("read error:", e)
        time.sleep(1)

@app.route("/data")
def data():
    with lock:
        ts = [s[0] for s in samples]
        vs = [s[1] for s in samples]
        ch = channel
    return jsonify(channel=ch, name=NAMES[ch], unit="V", t=ts, v=vs)

@app.route("/select")
def select():
    global channel, samples, t0
    ch = request.args.get("ch", "0")
    if ch not in ("0", "1"):
        return "bad channel", 400
    with open(DEV, "w") as f:
        f.write(ch)
    with lock:
        channel = int(ch)
        samples = []           # reset del grafico al cambiar de senal
        t0 = time.time()
    return "ok"

@app.route("/")
def index():
    return HTML

HTML = """
<!doctype html><html lang="es"><head><meta charset="utf-8">
<title>TP5 - Senal vs tiempo</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<style>body{font-family:sans-serif;margin:2rem}button{padding:.5rem 1rem;margin-right:.5rem}#wrap{max-width:800px}</style>
</head><body><div id="wrap">
<h2 id="titulo">Senal</h2>
<button onclick="sel(0)">Senal 0 (diente de sierra)</button>
<button onclick="sel(1)">Senal 1 (cuadrada)</button>
<canvas id="chart"></canvas></div>
<script>
const chart = new Chart(document.getElementById('chart'), {
  type:'line',
  data:{labels:[],datasets:[{label:'Tension',data:[],borderColor:'#2563eb',tension:0}]},
  options:{animation:false,scales:{
    x:{title:{display:true,text:'Tiempo [s]'}},
    y:{title:{display:true,text:'Tension [V]'},min:0,max:3.3}}}
});
async function refresh(){
  const d = await (await fetch('/data')).json();
  document.getElementById('titulo').textContent = 'Senal: '+d.name+'  (canal '+d.channel+')';
  chart.data.labels = d.t;
  chart.data.datasets[0].label = 'Tension ['+d.unit+']';
  chart.data.datasets[0].data = d.v;
  chart.update();
}
async function sel(ch){ await fetch('/select?ch='+ch); await refresh(); }
setInterval(refresh, 1000); refresh();
</script></body></html>
"""

if __name__ == "__main__":
    threading.Thread(target=reader, daemon=True).start()
    app.run(host="0.0.0.0", port=8080)
