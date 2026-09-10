
class Categoria {
  const Categoria({
    required this.id,
    required this.icon,
    required this.nombre,
    required this.descripcion,
    required this.imagen,
  });

  final String id;
  final String icon;
  final String nombre;
  final String descripcion;
  final String imagen;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'icon': icon,
      'nombre': nombre,
      'descripcion': descripcion,
      'imagen': imagen,
    };
  }
}

const List<Categoria> categoriasCatalogo = [
  Categoria(
    id: 'cereales',
    icon: '🥣',
    nombre: 'Cereales',
    descripcion: 'Desayunos saludables',
    imagen: 'assets/categorias/cereales.jpg',
  ),
  Categoria(
    id: 'bebidas',
    icon: '🥤',
    nombre: 'Bebidas',
    descripcion: 'Refrescos y jugos',
    imagen: 'assets/categorias/bebidas.jpg',
  ),
  Categoria(
    id: 'frutas',
    icon: '🍎',
    nombre: 'Frutas / Verduras',
    descripcion: 'Frescura local',
    imagen: 'assets/categorias/frutas.jpg',
  ),
  Categoria(
    id: 'jugos',
    icon: '🧃',
    nombre: 'Jugos / Infusiones',
    descripcion: 'Naturales y sin azúcar',
    imagen: 'assets/categorias/jugos.jpg',
  ),
  Categoria(
    id: 'postres',
    icon: '🍰',
    nombre: 'Postres / Meriendas',
    descripcion: 'Dulces artesanales',
    imagen: 'assets/categorias/postres.jpg',
  ),
  Categoria(
    id: 'matesAccesorios',
    icon: '🧉',
    nombre: 'Mates y Accesorios',
    descripcion: 'Mates, bombillas y accesorios',
    imagen: 'assets/categorias/matesAccesorios.jpg',
  ),
  Categoria(
    id: 'mas',
    icon: '🛍️',
    nombre: 'Más',
    descripcion: 'Más objetos y cosas para vender',
    imagen: '',
  ),
];