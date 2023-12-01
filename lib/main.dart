import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
///librerias para custum image labeling
//import 'dart:io' as io;
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
//librerias para video de fondo
import 'package:video_player/video_player.dart';
import 'package:identificador_foto/full_screen_player.dart';

//imports para el detector de objetos
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';


//importe de archivos
import 'app_theme.dart';//tema app
//base de datos con la informacion de las plantas
import 'lista_datos_identificacion.dart';


late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IDENTIFICADOR PLANTAS',
      theme: AppTheme().getTheme(),
      home: Scaffold(
        body: CameraApp(),
    ),
   ),
  );
}

/// CameraApp is the Main Application.
class CameraApp extends StatefulWidget {
  /// Default Constructor
  CameraApp({super.key});
  @override
  State<CameraApp> createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  late ImagePicker imagePicker;
  //colores del fondo
  final  Color colorFondo1 = Color.fromARGB(255, 202, 171, 211);
  final Color colorFondo2 = Color.fromARGB(255, 46, 11, 56);
  //direccion imagen
  var imagenInicio  = 'assets/images/udi_logo_sin_fondo.png';
  var imagenBotonFoto  =  'assets/images/frailejon_sin_fondo2.png';
  final imagenFondo = 'assets/images/frailejon_sin_fondo2.png';
  var imagenIdentificada  =  'assets/images/manzana.png';
  bool banderaAbrirFichaTecnica = false;
  
  //tamamaño imagen de la preview de la camara
  final double tamanoFoto  = 600;
  File? imageFile;
  File? _selectedImage;
  //variable con la imagen para dibujar los rectangulos del detector
  var imageConBoundingBox;
  //variable que almacena el resultado de la identificacion
  String result = '0';
  //intanciar modulo fotos con camara
  //final imagePicker = ImagePicker(); 

  //crear vaariable para las clases de la identificacion
  //declarar image laberer
  dynamic imageLabeler;
  //declarar detector de objetos
  dynamic objectDetector;


  //crea la variable del video player
  late VideoPlayerController controller;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    imagePicker = ImagePicker();
    //TODO initialize labeler
    createLabeler();
    //inicializar detector de objetos default de la libreria de google
    // final mode = DetectionMode.single;//.stream para camara en vivo
    // // Options to configure the detector while using with base model.
    // final options = ObjectDetectorOptions(classifyObjects: true, mode: mode,multipleObjects: true);
    // // Options to configure the detector while using a local custom model.
    // //final options = LocalObjectDetectorOptions(...);
    // objectDetector = ObjectDetector(options: options);

    //// inicializar el detector de objetos
    createObjectDetector();


  }

  ///////////////////////////////////////////////////////////////////////
  //funcion para tomar foto desde la camara
  ///////////////////////////////////////////////////////////////////////
  _takePicture() async {
    final pickedImage = await imagePicker.pickImage(source: ImageSource.camera, maxWidth: tamanoFoto);
    if (pickedImage == null){
      return;
    } 
    setState(() {
      _selectedImage = File(pickedImage.path);
      ///inicializar en el arranque  modelo imagelabeler default
      //final ImageLabelerOptions options = ImageLabelerOptions(confidenceThreshold: 0.8);
      //imageLabeler = ImageLabeler(options: options);

      //llamar en el arranque de la app el modelo tflite para clasificacion imagenes
      //createLabeler();
      //doImageLabeling();
      doObjectDetection();
    
    });
  }
///////////////////////////////////////////////////////////////////////
////metodo para utilizar la clasificacion desde la galeria 
///////////////////////////////////////////////////////////////////////
  _imgFromGallery() async {
    XFile? pickedFile = await imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        //llamar en el arranque de la app el modelo tflite para clasificar imagenes
        // createLabeler();
        // doImageLabeling();
        //llamar detector de objetos 
        doObjectDetection();
      });
    }
  }
/////metododo para clasificar imaenes con modelo custom
///metodo para llamar modelo tflite cutom
createLabeler() async {
  final modelPath = await _getModel('assets/ml/model_frutas.tflite');
  final options = LocalLabelerOptions(confidenceThreshold: 0.5, modelPath: modelPath,);
  imageLabeler = ImageLabeler(options: options);
}
///////////////////////////////////////////////////////////////////////
////metodo para llamar el modelo tflite custom  para solo clasificacion de objetos
//////////////////////////////////////////////////////////////////////////
Future<String> _getModel(String assetPath) async {
  if (Platform.isAndroid) {
    return 'flutter_assets/$assetPath';
  }
  final path = '${(await getApplicationSupportDirectory()).path}/$assetPath';
  await Directory(dirname(path)).create(recursive: true);
  final file = File(path);
  if (!await file.exists()) {
    final byteData = await rootBundle.load(assetPath);
    await file.writeAsBytes(byteData.buffer
        .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
  }
  return file.path;
}

///////////////////////////////////////////////////////////////////////////
////metodo para llamar el modelo tflite custom para deteccion de objetos 
//////////////////////////////////////////////////////////////////////////
Future<String> getModelPath(String asset) async {
  final path = '${(await getApplicationSupportDirectory()).path}/$asset';
  await Directory(dirname(path)).create(recursive: true);
  final file = File(path);
  if (!await file.exists()) {
    final byteData = await rootBundle.load(asset);
    await file.writeAsBytes(byteData.buffer
            .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
  }
  return file.path;
}
///////////////////////////////////////////////////////////////////////////
////metodo para crear el modelo tflite custom para deteccion de objetos 
///aqui se utiliza un clasificador de objetos dentro del detector de objetos
//////////////////////////////////////////////////////////////////////////
createObjectDetector() async {
  final modelPath = await getModelPath('assets/ml/model_clasificador_plantas_efficient1.tflite'); //para reconocer frutas colocar model_frutas
  final options = LocalObjectDetectorOptions(
  mode: DetectionMode.single,
  modelPath: modelPath,
  classifyObjects: true,
  multipleObjects: false,
);
  objectDetector = ObjectDetector(options: options);
}
///////////////////////////////////////////////////////////////////////
  //metodo para detectar e identificar imagenes
///////////////////////////////////////////////////////////////////////
///inicializar variables del detector con retardo de tiempo
late List<DetectedObject> objects = [];
  doObjectDetection() async {
    InputImage inputImage = InputImage.fromFile(_selectedImage!);
    objects = await objectDetector.processImage(inputImage);
    //inicializa la variable de resultado de la identificacion
    result = '0';
    //extrae las bounding boxes
    for(DetectedObject detectedObject in objects){
      final rect = detectedObject.boundingBox;
      final trackingId = detectedObject.trackingId;
      //extrae los labels de cada categoria detectada
      for(Label label in detectedObject.labels){
        final String text = label.text;
        result = text;
        print('${label.text} ${label.confidence}');
      }

    }
      switch(result) { 
        case '': { 
            result = '0'; 
        } 
        break; 
        
        case '2': { 
             result = '2';  
        } 
        break; 

        case '3': { 
             result = '3';  
        } 
        break;
            
        default: { 
            result = '0';   
        }
        break; 
      }
    setState(() {
     

      result;
      objects;
    });
    /// dibujar rectangulos en la imagen
    drawRectanglesAroundObjects();
  }
    // //TODO draw rectangles
    var ancho;
    var alto;
  drawRectanglesAroundObjects() async {
    imageConBoundingBox = await _selectedImage?.readAsBytes();
    imageConBoundingBox = await decodeImageFromList(imageConBoundingBox);
    ancho = imageConBoundingBox.width.toDouble();
    alto = imageConBoundingBox.height.toDouble();
    setState(() {
      imageConBoundingBox;
      objects;
      ancho;
      alto;
      //result;
    });
  }

///////////////////////////////////////////////////////////////////////
  //metodo para identificar imagenes
///////////////////////////////////////////////////////////////////////
  doImageLabeling() async {
    InputImage inputImage = InputImage.fromFile(_selectedImage!);
    //procesa la imagen para adquirir la lista de clases
    final List<ImageLabel> labels = await imageLabeler.processImage(inputImage);
    //inicializa la variable de resultado de la identificacion
    result = '';
    //hace un barrido por las clases identificadas con su respectivo indice de confianza
    for (ImageLabel label in labels) {
      final String text = label.label;
      //final int index = label.index;
      final double confidence = label.confidence;
      result = text; 
      //result += text + ': ' + confidence.toStringAsFixed(2) + '\n'; 
      }
      // switch case para clasificar las plantas y colocar datos en tarjeta
      switch(result) { 
        case '': { 
            result = '0'; 
        } 
        break; 
        
        case '1': { 
             result = '2';  
        } 
        break; 

        case '2': { 
             result = '3';  
        } 
        break;
            
        default: { 
            result = '0';   
        }
        break; 
      }
      //actualiza la variable de reultado con las identifaciones 
      setState(() {
        result;
      });
  }

///////////////////////////////////////////////////////////////////////
//CONSTRUCCION PAGINA INICIO SI NO HAY FOTO PARA IDENTIFICAR
//esta pantalla da inicio con una imagen
Widget pantallaInicio(){
  return Stack(
      alignment: Alignment.center,
      children: [
        //fondo aplicacion
        SizedBox.expand(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors:  [colorFondo1,colorFondo2],begin: Alignment.topLeft,end: Alignment.bottomRight,),
          ),
          ),
          ),
        //fondo para imagen fondo
        Positioned(
          top: 300,
          child: Image.asset(imagenFondo ,width: 200),),
        //botones para tomar fotos o galeria
        Positioned(
          bottom: 100,
          right: 25,
          child: Column(
            children: [
              IconButton(//boton camara
                onPressed: _takePicture, 
                icon:const Icon(Icons.camera_alt,size: 50, color: Color.fromARGB(255, 243, 243, 243),),
                ),
              const SizedBox(height: 50),
              IconButton(//boton galeria
                onPressed: _imgFromGallery, 
                icon:const Icon(Icons.photo_album,size: 50, color: Color.fromARGB(255, 243, 243, 243),),
                ),

            ],
          ),
        ),
        //imagen icono UDI
        Positioned(
          bottom: 10,
          child: Image.asset(imagenInicio ,width: 100),),
        //degrade bonito
        //efectoDegradePantallaInicio()
      ],
    );
}

///////////////////////////////////////////////////////////////////////
//CONSTRUCCION PAGINA INICIO con video de fondo
Widget pantallaInicioVideo(){
  return Stack(
      alignment: Alignment.center,
      children: [
        //fondo aplicacion
        const SizedBox.expand(
          child: FullScreenPlayer(caption: 'hola', VideoUrl: 'assets/images/video_intro1.mp4',),
          ),
        //botones para tomar fotos o galeria
        Positioned(
          bottom: 100,
          right: 25,
          child: Column(
            children: [
              IconButton(//boton camara
                onPressed: _takePicture, 
                icon:const Icon(Icons.camera_alt,size: 50, color: Color.fromARGB(255, 243, 243, 243),),
                ),
              const SizedBox(height: 50),
              IconButton(//boton galeria
                onPressed: _imgFromGallery, 
                icon:const Icon(Icons.photo_album,size: 50, color: Color.fromARGB(255, 243, 243, 243),),
                ),

            ],
          ),
        ),
        //imagen icono UDI
        Positioned(
          bottom: 10,
          child: Image.asset(imagenInicio ,width: 100),),
        //nombre app
        const Positioned(
          bottom: 100,
          left: 25,
          child: Text('FloraBan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30, color: Color.fromARGB(255, 243, 243, 243))),
        ),
        //degrade bonito
        //efectoDegradePantallaInicio()
      ],
    );
}
//////////////////////////////////////////////////////////////////////////
/////degrade para efecto en pantalla
///////////////////////////////////////////////////////////////////////////
Widget efectoDegradePantallaInicio(){
  return const Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent,Colors.black87],
            stops: [ 0.8, 1.0 ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter
          )
        ),
      )
    );


}

///////////////////////////////////////////////////////////////////////
// metodo para construir tarjetas con la planta reconocida
///////////////////////////////////////////////////////////////////////
//tarjeta para mostrar identificacion
ListTile miTarjeta(){
  return ListTile(
                leading: Image.asset(fichaIdent[result]['img'][0],fit: BoxFit.cover),
                title: Text(fichaIdent[result]['nombre_comun'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color.fromARGB(255, 243, 243, 243))), //const Text('Titulo'),
                trailing: IconButton(//boton camara
                          onPressed: (){
                            setState(() {
                              banderaAbrirFichaTecnica = true;
                              //contend = pantallaFichaTecnica();
                            });
                          }, 
                          icon:const Icon(Icons.arrow_forward,size: 25, color: Color.fromARGB(255, 243, 243, 243),),
                ),
                subtitle: Text(fichaIdent[result]['descripcion_corta'], textAlign: TextAlign.justify, style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14, color: Color.fromARGB(255, 243, 243, 243))),
                selected: true,
              );
}
///////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////
  Widget pantallaMostrarIdentificador(){
    return Stack(
      alignment: Alignment.center,
      children: [
        //fondo aplicacion
        SizedBox.expand(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors:  [colorFondo1,colorFondo2],begin: Alignment.topLeft,end: Alignment.bottomRight,),
          ),),),
        //espacio para mostrar la imagen tomada
        Positioned(
          top: 30, ///adiciona la imagen con las boundingbox
          child:  Container(height: 500,width: 400, child: Center(child: FittedBox( child: SizedBox(width: ancho, height: alto, child: CustomPaint(child: Container(width: 300, height: 300),painter: ObjectPainter(objectList: objects, imageFile: imageConBoundingBox)))))),///Image.file(_selectedImage!, fit: BoxFit.cover, height: 500,width: 400),
          ),
        //tarjeta de informacion basica de identificacion
        Positioned(
          top: 530,
          child: SizedBox(
            width: 400,
            height: 200,
            child:Container(child: miTarjeta(), color:Colors.transparent,),),),
        //botones para activar camara o por galeria
        Positioned(
          bottom: 80,
          //right: 20,
          child: Row(
            children: [
              IconButton(//boton camara
                onPressed: _takePicture, 
                icon:const Icon(Icons.camera_alt,size: 40, color: Color.fromARGB(255, 243, 243, 243),),
                ),
              const SizedBox(width: 250),
              IconButton(//boton galeria
                onPressed: _imgFromGallery, 
                icon:const Icon(Icons.photo_album,size: 40, color: Color.fromARGB(255, 243, 243, 243),),
                ),

            ],
          ),
        ),
        //imagen icono UDI
        Positioned(
          bottom: 10,
          child: Image.asset(imagenInicio ,width: 100),),
      ]      

    );
  }

/////////////////////////////////////////////////////////////////////////
/// pantalla con la ficha tecnica de las plantas identificadas
/// /////////////////////////////////////////////////////////////////////
Widget pantallaFichaTecnica(){
  return Scaffold(
    floatingActionButton: FloatingActionButton(
      onPressed: (){
        setState(() {
          banderaAbrirFichaTecnica = false;
        });
      },
      child: const Icon(Icons.keyboard_return_outlined),),
    body: SingleChildScrollView(
      child: SizedBox(
        height: 1200,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors:  [colorFondo1,colorFondo2],begin: Alignment.topLeft,end: Alignment.bottomRight,),
            ),
            child: Column(
              children: [
                //imagen clasificada
                Stack(
                  children:<Widget>[ 
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          SizedBox(
                          //color: Colors.white,
                            height: 500,
                            width: 400,//double.infinity,
                            child: Image.asset(fichaIdent[result]['img'][0],fit: BoxFit.cover),),
                          SizedBox(
                          //color: Colors.white,
                            height: 500,
                            width:400,// double.infinity,
                            child: Image.asset(fichaIdent[result]['img'][1],fit: BoxFit.cover),),
                          SizedBox(
                          //color: Colors.white,
                            height: 500,
                            width:400,// double.infinity,
                            child: Image.asset(fichaIdent[result]['img'][2],fit: BoxFit.cover),),
                  ],),
                    ),
                    //nombre de la clase sobre la imagen
                    Positioned(
                      bottom: 40,
                      left: 30,
                      child: Text(fichaIdent[result]['nombre_comun'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 30, color: Color.fromARGB(255, 243, 243, 243))),)
                  ],),
                  ///mostrar informacion ficha tecnica
                  ///nombre cientifico
                  ListTile(
                    title: const Text('Nombre Científico :', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color.fromARGB(255, 243, 243, 243))),
                    subtitle: Text(fichaIdent[result]['nombre_cientifico'], style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14, color: Color.fromARGB(255, 243, 243, 243))),
                  ),
                  ListTile(
                    title: const Text('Familia :', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color.fromARGB(255, 243, 243, 243))),
                    subtitle: Text(fichaIdent[result]['familia'], style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14, color: Color.fromARGB(255, 243, 243, 243))),
                  ),
                  ListTile(
                    title: const Text('Género :', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color.fromARGB(255, 243, 243, 243))),
                    subtitle: Text(fichaIdent[result]['genero'], style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14, color: Color.fromARGB(255, 243, 243, 243))),
                  ),
                  ListTile(
                    title: const Text('Descripción :', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color.fromARGB(255, 243, 243, 243))),
                    subtitle: Text(fichaIdent[result]['descripcion'], textAlign: TextAlign.justify, style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14, color: Color.fromARGB(255, 243, 243, 243))),
                  ),
                  ListTile(
                    title: const Text('Región :', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color.fromARGB(255, 243, 243, 243))),
                    subtitle: Text(fichaIdent[result]['region'], style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14, color: Color.fromARGB(255, 243, 243, 243))),
                  ),
                  ListTile(
                    title: const Text('Estado de conservación :', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color.fromARGB(255, 243, 243, 243))),
                    subtitle: Text(fichaIdent[result]['estado'], style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14, color: Color.fromARGB(255, 243, 243, 243))),
                  ),
                
              ],),),
        ),
  ),
  );


  }

  @override
  Widget build(BuildContext context) {
      //construir un widget de boton con icono para mostrar si no hay foto 
      Widget contend = pantallaInicioVideo();//pantallaInicio();//pantallaInicioVideo();//pantallaFichaTecnica();//pantallaInicio();//inicio();    
      //condicion para mostrar la preview de la imagen
      if (_selectedImage != null){
        contend = pantallaMostrarIdentificador();
      }
      /////logica para mostrar pantallas
      setState(() {
        if (banderaAbrirFichaTecnica == true){
          contend = pantallaFichaTecnica();
        }
      });

    return contend;
  }
}
  

///////////////////////////////////////////////////////////////////////
/// esta clase realiza el dibujo de los rectangulos sobre la imagen
/// que recibe el detector de imagenes
////////////////////////////////////////////////////////////////////////

class ObjectPainter extends CustomPainter {
  List<DetectedObject> objectList;
  dynamic imageFile;
  ObjectPainter({required this.objectList, @required this.imageFile});

  @override
  void paint(Canvas canvas, Size size) {
    if (imageFile != null) {
      canvas.drawImage(imageFile, Offset.zero, Paint());
    }
    Paint p = Paint();
    p.color = Colors.red;
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 4;

    for (DetectedObject rectangle in objectList) {
      canvas.drawRect(rectangle.boundingBox, p);
      var list = rectangle.labels;
      for(Label label in list){
        print("${label.text}   ${label.confidence.toStringAsFixed(2)}");
        TextSpan span = TextSpan(text: label.text,style: const TextStyle(fontSize: 30,color: Colors.red));
        TextPainter tp = TextPainter(text: span, textAlign: TextAlign.left,textDirection: TextDirection.ltr);
        tp.layout();
        tp.paint(canvas, Offset(rectangle.boundingBox.left,rectangle.boundingBox.top));
        break;
      }
    }

  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}