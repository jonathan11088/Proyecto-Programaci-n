let monitor = null;
let periodo = 'hoy';

async function cargarCajeros() {
  const { cajeros } = await api('/admin/cajeros');
  const cuerpo = document.querySelector('#lista-cajeros');
  cuerpo.replaceChildren();
  if (cajeros.length === 0) {
    const fila = cuerpo.insertRow();
    celda(fila, 'Todavía no hay cajeros.').colSpan = 4;
    return;
  }
  for (const cajero of cajeros) {
    const bloqueado = Number(cajero.bloqueado) === 1;
    const fila = cuerpo.insertRow();
    celda(fila, cajero.nombre);
    celda(fila, cajero.usuario);
    celda(fila, bloqueado ? 'Bloqueado' : 'Activo', bloqueado ? 'estado-no' : 'estado-ok');
    const boton = document.createElement('button');
    boton.className = 'secundario pequeno';
    boton.textContent = bloqueado ? 'Desbloquear' : 'Bloquear';
    boton.addEventListener('click', async () => {
      boton.disabled = true;
      await api(`/admin/cajeros/${cajero.id}/bloqueo`, { bloqueado: !bloqueado });
      await cargarCajeros();
    });
    celda(fila, '').appendChild(boton);
  }
}

function metrica(valor, etiqueta, total) {
  const caja = document.createElement('div');
  caja.className = 'metrica';
  const numero = document.createElement('strong');
  numero.textContent = valor;
  const texto = document.createElement('span');
  texto.textContent = etiqueta;
  caja.append(numero, texto);
  if (total !== undefined) {
    const historico = document.createElement('small');
    historico.textContent = `Histórico: ${total}`;
    caja.append(historico);
  }
  return caja;
}

function dibujarGrafica() {
  const lienzo = document.querySelector('#grafica');
  const escala = window.devicePixelRatio || 1;
  const ancho = lienzo.clientWidth;
  const alto = lienzo.clientHeight;
  lienzo.width = ancho * escala;
  lienzo.height = alto * escala;
  const c = lienzo.getContext('2d');
  c.scale(escala, escala);
  c.clearRect(0, 0, ancho, alto);

  const barras = [
    { etiqueta: 'Depósitos', valor: Number(monitor[`monto_depositos_${periodo}`]), color: '#1d6fb8', colorBase: '#123c69' },
    { etiqueta: 'Retiros', valor: Number(monitor[`monto_retiros_${periodo}`]), color: '#f2c14e', colorBase: '#c98a00' },
  ];
  const maximo = Math.max(...barras.map((b) => b.valor), 1);
  const base = alto - 36;
  const techo = 34;
  const anchoBarra = Math.min(ancho / 4, 140);

  c.strokeStyle = '#d6dee7';
  c.beginPath();
  c.moveTo(0, base + 0.5);
  c.lineTo(ancho, base + 0.5);
  c.stroke();

  c.textAlign = 'center';
  barras.forEach((barra, i) => {
    const x = (ancho * (i * 2 + 1)) / 4;
    const h = (barra.valor / maximo) * (base - techo);
    const relleno = c.createLinearGradient(0, base - h, 0, base);
    relleno.addColorStop(0, barra.color);
    relleno.addColorStop(1, barra.colorBase);
    c.fillStyle = relleno;
    c.beginPath();
    c.roundRect(x - anchoBarra / 2, base - h, anchoBarra, h, [10, 10, 0, 0]);
    c.fill();
    c.fillStyle = '#1c2733';
    c.font = '600 14px system-ui, sans-serif';
    c.fillText(quetzales(barra.valor), x, base - h - 10);
    c.font = '14px system-ui, sans-serif';
    c.fillText(barra.etiqueta, x, base + 24);
  });
}

async function cargarMonitor() {
  monitor = await api('/admin/monitor');
  document.querySelector('#metricas').replaceChildren(
    metrica(monitor.cuentas_hoy, 'Cuentas creadas hoy'),
    metrica(monitor.clientes_hoy, 'Usuarios cliente registrados hoy'),
    metrica(monitor.transacciones_hoy, 'Transacciones hoy', monitor.transacciones_total),
    metrica(monitor.depositos_hoy, 'Depósitos hoy', monitor.depositos_total),
    metrica(monitor.retiros_hoy, 'Retiros hoy', monitor.retiros_total),
  );
  dibujarGrafica();
}

function elegirPeriodo(nuevo) {
  periodo = nuevo;
  document.querySelector('#grafica-hoy').setAttribute('aria-pressed', String(nuevo === 'hoy'));
  document.querySelector('#grafica-total').setAttribute('aria-pressed', String(nuevo === 'total'));
  if (monitor) dibujarGrafica();
}

document.querySelector('#grafica-hoy').addEventListener('click', () => elegirPeriodo('hoy'));
document.querySelector('#grafica-total').addEventListener('click', () => elegirPeriodo('total'));
window.addEventListener('resize', () => {
  if (monitor && !document.querySelector('#monitor').hidden) dibujarGrafica();
});

elegirPeriodo('hoy');
conectarFormulario(document.querySelector('#form-cajero'), '/admin/cajeros', cargarCajeros);
iniciarPanel('admin', (seccion) => {
  if (seccion === 'cajeros') cargarCajeros();
  if (seccion === 'monitor') cargarMonitor();
});
