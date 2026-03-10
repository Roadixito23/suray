import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';
import 'floating_notification.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Controladores de tabs para cada ciudad
  int _puertoAysenTabIndex = 0;
  int _coyhaiqueTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Función para copiar al portapapeles y llamar
  Future<void> _makePhoneCall(String phoneNumber) async {
    // Limpiar el número de teléfono (eliminar espacios)
    final cleanNumber = phoneNumber.replaceAll(' ', '');

    // Copiar al portapapeles
    await Clipboard.setData(ClipboardData(text: cleanNumber));

    // Mostrar mensaje de confirmación
    if (mounted) {
      FloatingNotification.show(
        context,
        message: 'Número $cleanNumber copiado al portapapeles',
        type: NotificationType.success,
        duration: const Duration(seconds: 2),
      );
    }

    // Intentar abrir el marcador telefónico
    final Uri phoneUri = Uri(scheme: 'tel', path: cleanNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  // Función para copiar email y abrir gestor de correo
  Future<void> _sendEmail(String email) async {
    // Copiar al portapapeles
    await Clipboard.setData(ClipboardData(text: email));

    // Mostrar mensaje de confirmación
    if (mounted) {
      FloatingNotification.show(
        context,
        message: 'Correo $email copiado al portapapeles',
        type: NotificationType.success,
        duration: const Duration(seconds: 2),
      );
    }

    // Intentar abrir gestor de correo
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Consulta desde suray.cl',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  // Función para abrir Google Maps
  Future<void> _openMap(String mapUrl) async {
    final Uri uri = Uri.parse(mapUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        FloatingNotification.show(
          context,
          message: 'No se pudo abrir el mapa. Inténtalo nuevamente',
          type: NotificationType.error,
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SelectionArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                MyApp.lightGreyBackground,
                MyApp.surfaceWhite,
                MyApp.primaryNavy.withOpacity(0.05),
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
          child: CustomScrollView(
            slivers: [
              // AppBar moderna con gradiente
              SliverAppBar(
                expandedHeight: 200.0,
                floating: false,
                pinned: true,
                elevation: 0,
                backgroundColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          MyApp.primaryNavy,
                          MyApp.lightNavy,
                          MyApp.primaryOrange.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Patrón de fondo sutil
                        Positioned.fill(
                          child: Opacity(
                            opacity: 0.1,
                            child: Container(
                              decoration: const BoxDecoration(
                                image: DecorationImage(
                                  image: AssetImage(
                                    'assets/home_panels/buses.png',
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Contenido del header
                        Positioned(
                          bottom: 40,
                          left: 20,
                          right: 20,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ponte en Contacto',
                                  style: TextStyle(
                                    fontFamily: 'Hemiheads',
                                    fontSize: 32,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Para consultar por horarios, información sobre encomiendas o servicios especiales, puedes usar los siguientes canales de comunicación:',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),

              // Contenido principal
              SliverPadding(
                padding: const EdgeInsets.all(20.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            _buildLocationSection(),

                            const SizedBox(height: 24),

                            // Tarjetas de contacto
                            _buildSpecialServicesCard(),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MyApp.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MyApp.primaryNavy.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: MyApp.borderColor.withOpacity(0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  MyApp.primaryOrange.withOpacity(0.1),
                  MyApp.primaryNavy.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              size: 40,
              color: MyApp.primaryOrange,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Ponte en Contacto',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Para consultar por horarios, información sobre encomiendas o servicios especiales, puedes usar los siguientes canales de comunicación:',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String content,
    required Color color,
    int delay = 0,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 600 + delay),
        curve: Curves.easeOutCubic,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MyApp.surfaceWhite,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(color: color.withOpacity(0.2), width: 1),
              image: const DecorationImage(
                image: AssetImage('assets/home_panels/buses.png'),
                fit: BoxFit.cover,
                opacity: 0.1,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: onTap,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: color.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    content,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: color,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.touch_app_rounded,
                                  size: 14,
                                  color: color.withOpacity(0.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Column(
      children: [
        // Puerto Aysén
        _buildLocationCard(
          city: 'Puerto Aysén',
          locations: [
            LocationInfo(
              type: 'Oficina de venta de pasajes',
              address: 'Eusebio Ibar 630',
              phone: '672 336222',
              icon: Icons.business_rounded,
              mapUrl: 'https://maps.app.goo.gl/1nv7mAcGRpFVPMacA',
            ),
            LocationInfo(
              type: 'Oficina de correspondencia',
              address: 'Eusebio Ibar 630 (interior)',
              phone: '672 336231',
              icon: Icons.business_rounded,
              mapUrl: 'https://maps.app.goo.gl/1nv7mAcGRpFVPMacA',
            ),
          ],
          color: MyApp.primaryNavy,
          delay: 300,
          backgroundImage: 'assets/home_panels/aysen.png',
          tabIndex: _puertoAysenTabIndex,
          onTabChange: (index) {
            setState(() {
              _puertoAysenTabIndex = index;
            });
          },
        ),

        const SizedBox(height: 20),

        // Coyhaique
        _buildLocationCard(
          city: 'Coyhaique',
          locations: [
            LocationInfo(
              type: 'Oficina de venta de pasajes',
              address:
                  'Av. Norte Sur/Las Violetas, Terminal de Coyhaique, Of. N°2',
              phone: '672 212639',
              icon: Icons.location_city_rounded,
              mapUrl: 'https://maps.app.goo.gl/9AJMknQmkmf3tHSo8',
            ),
            LocationInfo(
              type: 'Oficina de correspondencia',
              address: 'Arturo Prat 265 (interior)',
              phone: '672 234085',
              icon: Icons.location_city_rounded,
              mapUrl: 'https://maps.app.goo.gl/pMdzjb5y1Mg1iNQd9',
            ),
          ],
          color: MyApp.accentBlue,
          delay: 400,
          backgroundImage: 'assets/home_panels/coyhaique.jpg',
          tabIndex: _coyhaiqueTabIndex,
          onTabChange: (index) {
            setState(() {
              _coyhaiqueTabIndex = index;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSpecialServicesCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: MyApp.surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: MyApp.primaryOrange.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: MyApp.primaryOrange.withOpacity(0.2),
            width: 1,
          ),
          image: const DecorationImage(
            image: AssetImage('assets/home_panels/buses.png'),
            fit: BoxFit.cover,
            opacity: 0.4,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Servicios Especiales',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: MyApp.primaryOrange),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: MyApp.primaryOrange.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.email_rounded,
                    size: 20,
                    color: MyApp.primaryOrange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _sendEmail('suray.ltda@gmail.com'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: MyApp.primaryOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: MyApp.primaryOrange.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'suray.ltda@gmail.com',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: MyApp.primaryOrange,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.touch_app_rounded,
                              size: 14,
                              color: MyApp.primaryOrange.withOpacity(0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard({
    required String city,
    required List<LocationInfo> locations,
    required Color color,
    int delay = 0,
    String? backgroundImage,
    required int tabIndex,
    required Function(int) onTabChange,
  }) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 600 + delay),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: MyApp.surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.2), width: 1),
          image:
              backgroundImage != null
                  ? DecorationImage(
                    image: AssetImage(backgroundImage),
                    fit: BoxFit.cover,
                    opacity: 0.15,
                  )
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con título
            Container(
              padding: const EdgeInsets.all(24),
              child: Text(
                city,
                style: TextStyle(
                  fontFamily: 'Hemiheads',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),

            // Mini AppBar con tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.1), width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      label: 'Ubícanos',
                      icon: Icons.location_on_rounded,
                      isSelected: tabIndex == 0,
                      color: color,
                      onTap: () => onTabChange(0),
                    ),
                  ),
                  Expanded(
                    child: _buildTabButton(
                      label: 'Horarios',
                      icon: Icons.access_time_rounded,
                      isSelected: tabIndex == 1,
                      color: color,
                      onTap: () => onTabChange(1),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Contenido según la tab seleccionada
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.1, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child:
                    tabIndex == 0
                        ? _buildLocationContent(locations, color)
                        : _buildScheduleContent(city, color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : color.withOpacity(0.6),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : color.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationContent(List<LocationInfo> locations, Color color) {
    return Column(
      key: const ValueKey('location'),
      children:
          locations
              .map((location) => _buildLocationItem(location, color))
              .toList(),
    );
  }

  Widget _buildScheduleContent(String city, Color color) {
    return Column(
      key: const ValueKey('schedule'),
      children: [
        // Oficina de Pasajes
        _buildScheduleSection(
          title: 'Oficina de Pasajes',
          icon: Icons.confirmation_number_rounded,
          color: color,
          schedules: _getTicketOfficeSchedules(city),
        ),

        const SizedBox(height: 16),

        // Oficina de Correspondencia
        _buildScheduleSection(
          title: 'Oficina de Correspondencia',
          icon: Icons.mail_rounded,
          color: color,
          schedules: _getMailOfficeSchedules(city),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getTicketOfficeSchedules(String city) {
    // Horario específico para domingo según la ciudad
    String sundayHours =
        city == 'Coyhaique'
            ? '10:00 - 15:30  /  18:00 - 19:15'
            : '08:00 - 13:30  /  16:30 - 18:00';

    return [
      {'day': 'Lunes a Viernes', 'hours': '06:30 - 19:00'},
      {'day': 'Sábado', 'hours': '08:00 - 19:00'},
      {'day': 'Domingo', 'hours': sundayHours},
    ];
  }

  List<Map<String, dynamic>> _getMailOfficeSchedules(String city) {
    return [
      {'day': 'Lunes a Viernes', 'hours': '09:00 - 13:30  /  15:18 - 19:00'},
      {'day': 'Sábado', 'hours': '10:00 - 13:00'},
      {'day': 'Domingo', 'hours': 'Cerrado'},
    ];
  }

  Widget _buildScheduleSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Map<String, dynamic>> schedules,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Tabla estilo Excel
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Encabezado de la tabla
                Container(
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(6),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: color.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Text(
                            'Día',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 12,
                          ),
                          child: Text(
                            'Horario',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Filas de datos
                ...schedules.map((schedule) {
                  final day = schedule['day'] as String;
                  final hours = schedule['hours'] as String;
                  final isClosed = hours == 'Cerrado';

                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: color.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      color:
                          isClosed
                              ? Colors.red.withOpacity(0.05)
                              : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        // Columna Día
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: color.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Text(
                              day,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: color.withOpacity(0.9),
                              ),
                            ),
                          ),
                        ),
                        // Columna Horario
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 12,
                            ),
                            child: _buildHoursCell(hours, isClosed, color),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoursCell(String hours, bool isClosed, Color color) {
    // Si contiene el separador "/", dividir en dos líneas
    if (hours.contains('/')) {
      final parts = hours.split('/').map((e) => e.trim()).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children:
            parts.map((part) {
              return Text(
                part,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.85),
                  height: 1.4,
                ),
              );
            }).toList(),
      );
    }

    // Si no tiene separador, mostrar normalmente
    return Text(
      hours,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isClosed ? Colors.red.withOpacity(0.8) : color.withOpacity(0.85),
      ),
    );
  }

  Widget _buildLocationItem(LocationInfo info, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(info.icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  info.type,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.location_on_rounded, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _openMap(info.mapUrl),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: color.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            info.address,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.touch_app_rounded,
                          size: 14,
                          color: color.withOpacity(0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.phone_rounded, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _makePhoneCall(info.phone),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: color.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            info.phone,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.touch_app_rounded,
                          size: 14,
                          color: color.withOpacity(0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LocationInfo {
  final String type;
  final String address;
  final String phone;
  final IconData icon;
  final String mapUrl;

  LocationInfo({
    required this.type,
    required this.address,
    required this.phone,
    required this.icon,
    required this.mapUrl,
  });
}
