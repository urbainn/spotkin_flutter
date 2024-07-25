import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;
import 'package:spotify/spotify.dart';

class SpotifyService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _accessTokenKey = 'accessToken';
  static const String _refreshTokenKey = 'refreshToken';

  late SpotifyApi _spotify;
  final String clientId;
  final String clientSecret;
  final String redirectUri;
  final String scope;

  SpotifyService({
    required this.clientId,
    required this.clientSecret,
    required this.redirectUri,
    required this.scope,
  }) {
    _initializeSpotify();
  }

  void _initializeSpotify() {
    final credentials = SpotifyApiCredentials(clientId, clientSecret);
    _spotify = SpotifyApi(credentials);
  }

  Future<void> exchangeCodeForToken(String code) async {
    final tokenEndpoint = Uri.parse('https://accounts.spotify.com/api/token');
    final response = await http.post(
      tokenEndpoint,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
        'client_id': clientId,
        'client_secret': clientSecret,
      },
    );

    if (response.statusCode == 200) {
      final tokenData = json.decode(response.body);
      final accessToken = tokenData['access_token'];
      final refreshToken = tokenData['refresh_token'];
      await _secureStorage.write(key: _accessTokenKey, value: accessToken);
      await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
      print('Access Token: $accessToken');
      _spotify = SpotifyApi(SpotifyApiCredentials(clientId, clientSecret,
          accessToken: accessToken));
    } else {
      print('Failed to exchange code for token: ${response.body}');
      throw Exception('Failed to authenticate with Spotify');
    }
  }

  void initiateSpotifyLogin() {
    final spotifyAuthUrl = Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'scope': scope,
    });

    print('Redirecting to: $spotifyAuthUrl');
    html.window.location.href = spotifyAuthUrl.toString();
  }

  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: _accessTokenKey);
  }

  Future<void> refreshAccessToken() async {
    final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    final tokenEndpoint = Uri.parse('https://accounts.spotify.com/api/token');
    final response = await http.post(
      tokenEndpoint,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': clientId,
        'client_secret': clientSecret,
      },
    );

    if (response.statusCode == 200) {
      final tokenData = json.decode(response.body);
      final accessToken = tokenData['access_token'];
      await _secureStorage.write(key: _accessTokenKey, value: accessToken);
      print('Access Token refreshed: $accessToken');
      _spotify = SpotifyApi(SpotifyApiCredentials(clientId, clientSecret,
          accessToken: accessToken));
    } else {
      print('Failed to refresh token: ${response.body}');
      throw Exception('Failed to refresh token');
    }
  }

  Future<void> _ensureAuthenticated() async {
    final accessToken = await getAccessToken();
    if (accessToken == null) {
      throw Exception('Not authenticated');
    }
    _spotify = SpotifyApi(SpotifyApiCredentials(clientId, clientSecret,
        accessToken: accessToken));
  }

  Future<Playlist> fetchPlaylist(String playlistId) async {
    await _ensureAuthenticated();
    try {
      return await _spotify.playlists.get(playlistId);
    } catch (e) {
      print('Error fetching playlist: $e');
      rethrow;
    }
  }

  Future<List<PlaylistSimple>> getUserPlaylists(String userId) async {
    await _ensureAuthenticated();
    final playlists = await _spotify.playlists.getUsersPlaylists(userId).all();
    return playlists.toList();
  }

  Future<void> updatePlaylist(String playlistId,
      {String? name, String? description}) async {
    await _ensureAuthenticated();
    // await _spotify.playlists.changePlaylistDetails(playlistId, name: name, description: description);
  }

  Future<Artist> getArtist(String artistId) async {
    await _ensureAuthenticated();
    return await _spotify.artists.get(artistId);
  }

  Future<Iterable<Track>> getPlaylistTracks(String playlistId) async {
    await _ensureAuthenticated();
    return await _spotify.playlists.getTracksByPlaylistId(playlistId).all();
  }

  Future<void> logout() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    _initializeSpotify();
  }

  // Future<Map<String, List>> search(String query, {int limit = 20}) async {
  //   try {
  //     print('Performing search for query: $query with limit: $limit');
  //     final searchResults = await _spotify.search.get(query).first(limit);

  //     print('Number of pages: ${searchResults.length}');

  //     final tracks = <Track>[];
  //     final artists = <Artist>[];
  //     final playlists = <PlaylistSimple>[];

  //     for (var page in searchResults) {
  //       print('Page type: ${page.runtimeType}');
  //       if (page.items != null) {
  //         print('Items type: ${page.items!.runtimeType}');
  //         print('Number of items: ${page.items!.length}');
  //         if (page.items!.isNotEmpty) {
  //           print('First item type: ${page.items!.first.runtimeType}');
  //         }
  //       }

  //       // Attempt to cast items based on their actual type
  //       if (page.items != null) {
  //         if (page.items!.isNotEmpty && page.items!.first is Track) {
  //           tracks.addAll(page.items!.cast<Track>());
  //         } else if (page.items!.isNotEmpty && page.items!.first is Artist) {
  //           artists.addAll(page.items!.cast<Artist>());
  //         } else if (page.items!.isNotEmpty &&
  //             page.items!.first is PlaylistSimple) {
  //           playlists.addAll(page.items!.cast<PlaylistSimple>());
  //         }
  //       }
  //     }

  //     print('Extracted results:');
  //     print('Tracks: ${tracks.length}');
  //     print('Artists: ${artists.length}');
  //     print('Playlists: ${playlists.length}');

  //     return {
  //       'tracks': tracks,
  //       'artists': artists,
  //       'playlists': playlists,
  //     };
  //   } catch (e) {
  //     print('Error searching Spotify: $e');
  //     return {
  //       'tracks': <Track>[],
  //       'artists': <Artist>[],
  //       'playlists': <PlaylistSimple>[],
  //     };
  //   }
  // }

  Future<Iterable<dynamic>> search(
    String query, {
    int limit = 20,
    required List<SearchType> types,
  }) async {
    try {
      print('Performing search for query: $query with limit: $limit');
      final searchResults =
          await _spotify.search.get(query, types: types).first(limit);

      print('Number of pages: ${searchResults.length}');

      final unifiedResults = <dynamic>[];

      for (var page in searchResults) {
        if (page.items != null) {
          unifiedResults.addAll(page.items!);
        }
      }

      print('Total number of results: ${unifiedResults.length}');

      return unifiedResults;
    } catch (e) {
      print('Error searching Spotify: $e');
      return [];
    }
  }

  Iterable<T> _extractItems<T>(List<Page> pages) {
    for (var page in pages) {
      if (page is Page<T>) {
        print('Extracting items of type $T, count: ${page.items?.length ?? 0}');
        return page.items ?? [];
      }
    }
    print('No items found of type $T');
    return [];
  }
}