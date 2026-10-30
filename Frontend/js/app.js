// Utilidades compartidas por todas las paginas.
const PANELES = { admin: 'admin.html', cajero: 'cajero.html', cliente: 'cliente.html' };

async function api(ruta, datos) {
  const opciones = { credentials: 'same-origin' };
  if (datos !== undefined) {
    opciones.method = 'POST';
    opciones.headers = { 'Content-Type': 'application/json' };
    opciones.body = JSON.stringify(datos);
  }
  let respuesta;
  try {
    respuesta = await fetch('/api' + ruta, opciones);
  } catch {
    throw Object.assign(new Error('No se pudo conectar con el servidor.'), { estado: 0 });
  }
  const cuerpo = await respuesta.json().catch(() => ({}));
  if (!respuesta.ok) {
    throw Object.assign(new Error(cuerpo.error || 'Ocurrió un error.'), { estado: respuesta.status });
  }
  return cuerpo;
}

function quetzales(valor) {
  return 'Q ' + Number(valor).toLocaleString('es-GT', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function celda(fila, contenido, clase) {
  const td = document.createElement('td');
  td.textContent = contenido;
  if (clase) td.className = clase;
  fila.appendChild(td);
  return td;
}

function avisar(formulario, mensaje, tipo) {
  let aviso = formulario.querySelector('.aviso');
  if (!aviso) {
    aviso = document.createElement('div');
    aviso.setAttribute('role', 'status');
    formulario.prepend(aviso);
  }
  aviso.className = 'aviso ' + tipo;
  aviso.textContent = mensaje;
}

// Envia un formulario como JSON y muestra el resultado dentro del mismo formulario.
function conectarFormulario(formulario, ruta, alTerminar) {
  formulario.addEventListener('submit', async (evento) => {
    evento.preventDefault();
    const boton = formulario.querySelector('button[type="submit"]');
    boton.disabled = true;
    try {
      const resultado = await api(ruta, Object.fromEntries(new FormData(formulario)));
      formulario.reset();
      avisar(formulario, resultado.mensaje || 'Operación realizada.', 'exito');
      if (alTerminar) await alTerminar(resultado);
    } catch (error) {
      if (error.estado === 401) { location.href = 'index.html'; return; }
      avisar(formulario, error.message, 'error');
    } finally {
      boton.disabled = false;
    }
  });
}

// Verifica la sesion y el rol del panel, y prepara encabezado y pestanas.
async function iniciarPanel(rol, alCambiarPestana) {
  let usuario;
  try {
    usuario = await api('/auth/me');
  } catch {
    location.replace('login.html?rol=' + rol);
    return null;
  }
  if (usuario.rol !== rol) {
    location.replace(PANELES[usuario.rol]);
    return null;
  }
  document.querySelector('#nombre-usuario').textContent = usuario.nombre;
  document.querySelector('#salir').addEventListener('click', async () => {
    await api('/auth/logout', {}).catch(() => {});
    location.href = 'index.html';
  });

  const botones = [...document.querySelectorAll('.pestanas button')];
  const mostrar = (boton) => {
    botones.forEach((b) => {
      const activa = b === boton;
      b.setAttribute('aria-selected', String(activa));
      document.getElementById(b.dataset.seccion).hidden = !activa;
    });
    if (alCambiarPestana) alCambiarPestana(boton.dataset.seccion);
  };
  botones.forEach((b) => b.addEventListener('click', () => mostrar(b)));
  document.querySelector('main').hidden = false;
  mostrar(botones[0]);
  return usuario;
}
