import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/user_model.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => UserModel(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Terpiez Game',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Terpiez Game'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: "List"),
            Tab(icon: Icon(Icons.map), text: "Finder"),
            Tab(icon: Icon(Icons.bar_chart), text: "Statistics"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ListTab(),
          FinderTab(),
          StatisticsTab(),
        ],
      ),
    );
  }
}

class ListTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final List<String> terpiezTypes = ['Terpiez Type 1', 'Terpiez Type 2', 'Terpiez Type 3'];

    return ListView.builder(
      itemCount: terpiezTypes.length,
      itemBuilder: (context, index) {
        String terpiezType = terpiezTypes[index];
        return ListTile(
          leading: Hero(
            tag: 'hero-$terpiezType',
            child: Icon(Icons.pets),
          ),
          title: Text(terpiezType),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => DetailsScreen(terpiezType: terpiezType)));
          },
        );
      },
    );
  }
}

class FinderTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: GestureDetector(
        onTap: () => Provider.of<UserModel>(context, listen: false).incrementTerpiez(),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Image.asset('assets/map.png'),
              SizedBox(height: 20), // Adds a bit of spacing
              Text('Tap anywhere on the map to capture Terpiez!'),
              SizedBox(height: 20), // Adds a bit of spacing
              Text('Distance to nearest Terpiez: 100m'), // Re-added text
            ],
          ),
        ),
      ),
    );
  }
}

class StatisticsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    UserModel userModel = Provider.of<UserModel>(context);
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
          child: IntrinsicHeight(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text('Total Captures: ${userModel.terpiezCaught}'),
                Text('Days Played: ${userModel.getDaysPlayed()}'),
                Text('User Id: ${userModel.userId}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DetailsScreen extends StatefulWidget {
  final String terpiezType;

  DetailsScreen({required this.terpiezType});

  @override
  _DetailsScreenState createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _animation = ColorTween(
      begin: Colors.blue,
      end: Colors.red,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Details of ${widget.terpiezType}')),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Hero(
                tag: 'hero-${widget.terpiezType}',
                child: Icon(Icons.pets, size: 100),
              ),
              SizedBox(height: 20),
              Text(widget.terpiezType, style: Theme.of(context).textTheme.headline5),
              SizedBox(height: 20),
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Container(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height - AppBar().preferredSize.height - MediaQuery.of(context).padding.top,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_animation.value!, Colors.yellow],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// class DetailsScreen extends StatelessWidget {
//   final String terpiezType;

//   DetailsScreen({required this.terpiezType});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Details of $terpiezType')),
//       body: SingleChildScrollView(
//         child: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Hero(
//                 tag: 'hero-$terpiezType',
//                 child: Icon(Icons.pets, size: 100),
//               ),
//               SizedBox(height: 20),
//               Text(terpiezType, style: Theme.of(context).textTheme.headline5),
//               AnimatedContainer(
//                 duration: Duration(seconds: 1),
//                 width: double.infinity,
//                 height: 200,
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                     colors: [Colors.blue, Colors.red],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
