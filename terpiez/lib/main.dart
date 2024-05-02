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
          tabs:  const [
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


// class ListTab extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return ListView(
//       children: <Widget>[
//         ListTile(
//           leading: Icon(Icons.pets),
//           title: Text('Terpiez Type 1'),
//           onTap: () {
//             Navigator.push(context, MaterialPageRoute(builder: (context) => DetailsScreen()));
//           },
//         ),
//         // Add more list tiles for other types
//       ],
//     );
//   }
// }

class ListTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Example list of Terpiez types
    final List<String> terpiezTypes = ['Terpiez Type 1', 'Terpiez Type 2', 'Terpiez Type 3'];

    return ListView.builder(
      itemCount: terpiezTypes.length,
      itemBuilder: (context, index) {
        String terpiezType = terpiezTypes[index];
        return ListTile(
          leading: Hero(
            tag: 'hero-$terpiezType', // Unique tag for each Hero
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
    return GestureDetector(
      onTap: () => Provider.of<UserModel>(context, listen: false).incrementTerpiez(),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset('assets/map.png'),
            Text('Tap anywhere on the map to capture Terpiez!'),
          ],
        ),
      ),
    );
  }
}


class StatisticsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    UserModel userModel = Provider.of<UserModel>(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text('Total Captures: ${userModel.terpiezCaught}'),
          Text('Days Played: ${userModel.getDaysPlayed()}'),
          Text('User Id: ${userModel.userId}'),

        ],
      ),
    );
  }
}

// class DetailsScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Terpiez Details')),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             Icon(Icons.pets, size: 100),
//             Text('Terpiez Name'),
//           ],
//         ),
//       ),
//     );
//   }
// }

class DetailsScreen extends StatelessWidget {
  final String terpiezType; // The type of Terpiez passed from the ListTab

  DetailsScreen({required this.terpiezType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Details of $terpiezType')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Hero(
              tag: 'hero-$terpiezType', // The same unique tag used in ListTab
              child: Icon(Icons.pets, size: 100),
            ),
            SizedBox(height: 20),
            Text(terpiezType, style: Theme.of(context).textTheme.headline5),
            AnimatedContainer(
              duration: Duration(seconds: 1),
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue, Colors.red],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


