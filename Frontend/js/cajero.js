function mostrarSaldo(formulario) {
  return ({ saldo }) => avisar(formulario, `Operación realizada. Nuevo saldo: ${quetzales(saldo)}`, 'exito');
}

const formDeposito = document.querySelector('#form-deposito');
const formRetiro = document.querySelector('#form-retiro');

conectarFormulario(document.querySelector('#form-cuenta'), '/cajero/cuentas');
conectarFormulario(formDeposito, '/cajero/depositos', mostrarSaldo(formDeposito));
conectarFormulario(formRetiro, '/cajero/retiros', mostrarSaldo(formRetiro));
iniciarPanel('cajero');
