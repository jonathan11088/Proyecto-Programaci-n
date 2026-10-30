const OPERACIONES = { apertura: 'Apertura de cuenta', deposito: 'Depósito', retiro: 'Retiro', transferencia: 'Transferencia' };
let listaTerceros = [];

async function cargarEstado() {
  const { cuenta, movimientos } = await api('/cliente/estado-cuenta');
  document.querySelector('#dato-cuenta').textContent = `${cuenta.nombre} · Cuenta ${cuenta.numero}`;
  document.querySelector('#dato-saldo').textContent = quetzales(cuenta.saldo);
  const cuerpo = document.querySelector('#lista-movimientos');
  cuerpo.replaceChildren();
  if (movimientos.length === 0) {
    celda(cuerpo.insertRow(), 'Todavía no hay operaciones.').colSpan = 6;
    return;
  }
  for (const m of movimientos) {
    const fila = cuerpo.insertRow();
    celda(fila, m.creado_en);
    celda(fila, OPERACIONES[m.tipo]);
    celda(fila, m.contraparte || '—');
    celda(fila, m.debito === null ? '' : quetzales(m.debito), 'num');
    celda(fila, m.credito === null ? '' : quetzales(m.credito), 'num');
    celda(fila, quetzales(m.saldo), 'num');
  }
}

function mostrarLimites() {
  const elegido = listaTerceros.find((t) => String(t.id) === document.querySelector('#selector-tercero').value);
  document.querySelector('#limites-tercero').textContent = elegido
    ? `Máximo por transferencia: ${quetzales(elegido.monto_maximo)}. Hoy: ${elegido.usadas_hoy} de ${elegido.max_transacciones} transferencias.`
    : 'Primero agregue una cuenta de tercero.';
}

async function cargarTerceros() {
  ({ terceros: listaTerceros } = await api('/cliente/terceros'));

  const cuerpo = document.querySelector('#lista-terceros');
  cuerpo.replaceChildren();
  if (listaTerceros.length === 0) {
    celda(cuerpo.insertRow(), 'Todavía no hay cuentas de terceros.').colSpan = 5;
  }
  const selector = document.querySelector('#selector-tercero');
  selector.replaceChildren();
  for (const t of listaTerceros) {
    const fila = cuerpo.insertRow();
    celda(fila, t.alias);
    celda(fila, t.numero);
    celda(fila, quetzales(t.monto_maximo), 'num');
    celda(fila, t.max_transacciones, 'num');
    celda(fila, t.usadas_hoy, 'num');
    selector.add(new Option(`${t.alias} (${t.numero})`, t.id));
  }
  mostrarLimites();
}

const formTransferencia = document.querySelector('#form-transferencia');
document.querySelector('#selector-tercero').addEventListener('change', mostrarLimites);
conectarFormulario(document.querySelector('#form-tercero'), '/cliente/terceros', cargarTerceros);
conectarFormulario(formTransferencia, '/cliente/transferencias', async ({ saldo }) => {
  await cargarTerceros();
  avisar(formTransferencia, `Transferencia realizada. Nuevo saldo: ${quetzales(saldo)}`, 'exito');
});

iniciarPanel('cliente', (seccion) => {
  if (seccion === 'estado') cargarEstado();
  else cargarTerceros();
});
