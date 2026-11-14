const { Router } = require('express');
const { verificarSesion } = require('../middlewares/auth.middleware');
const authCtrl = require('../controllers/auth.controller');
const rutaCtrl = require('../controllers/ruta.controller');
const reporteCtrl = require('../controllers/reporte.controller');
const gamifCtrl = require('../controllers/gamif.controller');

const router = Router();

router.post('/auth/registro', authCtrl.registrarUsuario);
router.post('/auth/login', authCtrl.iniciarSesion);
router.post('/bicicletas', verificarSesion, authCtrl.registrarBicicleta);

router.post('/rutas/calcular', verificarSesion, rutaCtrl.obtenerRuta);
router.get('/mapas/capas', rutaCtrl.listarCapas);

router.get('/bicicletas/verificar/:marco', reporteCtrl.verificarHurtoMarco);
router.get('/reportes', reporteCtrl.listarReportes);

router.get('/gamificacion/progreso', verificarSesion, gamifCtrl.obtenerProgreso);
router.post('/notificaciones/suscribir', verificarSesion, gamifCtrl.guardarSuscripcionPush);

module.exports = router;
