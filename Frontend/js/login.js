const TITULOS = { admin: 'Inicio de sesión de administrador', cajero: 'Inicio de sesión de cajero', cliente: 'Inicio de sesión de usuario' };
const rol = new URLSearchParams(location.search).get('rol');

if (!TITULOS[rol]) {
  location.replace('index.html');
} else {
  document.querySelector('#titulo').textContent = TITULOS[rol];
  if (rol === 'cliente') {
    document.querySelector('#etiqueta-usuario').textContent = 'Correo electrónico';
    document.querySelector('#usuario').type = 'email';
  }

  const formulario = document.querySelector('#formulario');
  formulario.addEventListener('submit', async (evento) => {
    evento.preventDefault();
    const boton = formulario.querySelector('button');
    boton.disabled = true;
    try {
      await api('/auth/login', { ...Object.fromEntries(new FormData(formulario)), rol });
      location.href = PANELES[rol];
    } catch (error) {
      avisar(formulario, error.message, 'error');
      boton.disabled = false;
    }
  });
}
