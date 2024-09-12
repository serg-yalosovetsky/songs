/*
 * This file is part of the Flutter Song Lyrics App.
 *
 * Flutter Song Lyrics App is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Flutter Song Lyrics App is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with Flutter Song Lyrics App.  If not, see <http://www.gnu.org/licenses/>.
 */

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const MyApp());
}

Future<Map<String, dynamic>> loadSongs() async {
  String jsonString = await rootBundle.loadString('assets/songs.json');
  return json.decode(jsonString);
}


class Song {
  final String name;
  final String text;

  Song({required this.name, required this.text});
}

class Artist {
  final String name;
  final List<Song> songs;

  Artist({required this.name, required this.songs});
}

class JsonLoader {  
  static Future<List<Artist>> loadArtists() async {
    String jsonString = await rootBundle.loadString('assets/progress.json');
    Map<String, dynamic> jsonData = json.decode(jsonString);
    
    List<Artist> artists = [];
    Map<String, dynamic> artistsData = jsonData['artists'];
    Map<String, dynamic> songsData = jsonData['songs'];

    artistsData.forEach((artistName, songUrls) {
      List<Song> artistSongs = [];
      for (String url in songUrls) {
        if (songsData.containsKey(url)) {
          artistSongs.add(Song(
            name: songsData[url]['name'],
            text: songsData[url]['text']
          ));
        }
      }
      if (artistSongs.isNotEmpty) {
        artistSongs.sort((a, b) => a.name.compareTo(b.name));
        artists.add(Artist(name: artistName, songs: artistSongs));
      }
    });
    artists.sort((a, b) => a.name.compareTo(b.name));

    return artists;
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Список виконавців',
      theme: ThemeData.dark().copyWith(
        primaryColor: Color(0xFF2BA0DA),
        scaffoldBackgroundColor: Colors.black,
        textTheme: TextTheme(
          bodyMedium: TextStyle(
            color: Colors.white,
          ),
        ),
      ),
      home: const ArtistListPage(title: 'Список виконавців'),
    );
  }
}

class ArtistListPage extends StatefulWidget {
  const ArtistListPage({super.key, required this.title});

  final String title;

  @override
  State<ArtistListPage> createState() => _ArtistListPageState();
}

class _ArtistListPageState extends State<ArtistListPage> {
  List<Artist> allArtists = [];
  List<Artist> filteredArtists = [];
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          if (searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  searchQuery = '';
                  filteredArtists = allArtists;
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              _showSearchModal(context);
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Artist>>(
        future: JsonLoader.loadArtists(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Помилка: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Немає даних'));
          }

          allArtists = snapshot.data!;
          filteredArtists = searchQuery.isEmpty
              ? allArtists
              : allArtists
                  .where((artist) => 
                      artist.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                      artist.songs.any((song) => song.name.toLowerCase().contains(searchQuery.toLowerCase())))
                  .toList();

          return ListView.separated(
            separatorBuilder: (context, index) => Divider(
              color: Colors.grey[800],
            ),
            itemCount: filteredArtists.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(filteredArtists[index].name),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                subtitle: Text(
                  'Пісень: ${filteredArtists[index].songs.length}',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SongListPage(
                        artist: filteredArtists[index],
                        initialSearchQuery: searchQuery.isNotEmpty &&
                                !filteredArtists[index].name.toLowerCase().contains(searchQuery.toLowerCase())
                            ? searchQuery
                            : '',
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showSearchModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Пошук виконавців та пісень',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
        );
      },
      isScrollControlled: true,
    );
  }
}

class SongListPage extends StatefulWidget {
  final Artist artist;
  final String initialSearchQuery;

  const SongListPage({
    Key? key,
    required this.artist,
    this.initialSearchQuery = '',
  }) : super(key: key);

  @override
  State<SongListPage> createState() => _SongListPageState();
}

class _SongListPageState extends State<SongListPage> {
  List<Song> filteredSongs = [];
  late String searchQuery;

  @override
  void initState() {
    super.initState();
    searchQuery = widget.initialSearchQuery;
    _filterSongs();
  }

  void _filterSongs() {
    filteredSongs = searchQuery.isEmpty
        ? widget.artist.songs
        : widget.artist.songs
            .where((song) => song.name
                .toLowerCase()
                .contains(searchQuery.toLowerCase()))
            .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Пісні ${widget.artist.name}'),
        actions: [
          if (searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  searchQuery = '';
                  _filterSongs();
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              _showSearchModal(context);
            },
          ),
        ],
      ),
      body: ListView.separated(
        separatorBuilder: (context, index) => Divider(
          color: Colors.grey[800],
        ),
        itemCount: filteredSongs.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(
              filteredSongs[index].name,
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SongPage(song: filteredSongs[index]),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showSearchModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Пошук пісень',
                prefixIcon: Icon(Icons.search),
              ),
              controller: TextEditingController(text: searchQuery),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                  _filterSongs();
                });
              },
            ),
          ),
        );
      },
      isScrollControlled: true,
    );
  }
}

class SongPage extends StatelessWidget {
  final Song song;

  const SongPage({Key? key, required this.song}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(song.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          song.text,
          style: const TextStyle(fontSize: 16.0),
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Ви натиснули кнопку цього разу:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
