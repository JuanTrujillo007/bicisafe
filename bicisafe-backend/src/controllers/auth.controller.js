const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');

const registrarUsuario = async (req, res) => {
  res.status(501).json({ mensaje: 'Endpoint RF-01 listo para implementación' });
};

const iniciarSesion = async (req, res) => {
  res.status(501).json({ mensaje: 'Endpoint RF-02 listo para implementación' });
};

const registrarBicicleta = async (req, res) => {
  res.status(501).json({ mensaje: 'Endpoint RF-03 listo para implementación' });
};

module.exports = { registrarUsuario, iniciarSesion, registrarBicicleta };
