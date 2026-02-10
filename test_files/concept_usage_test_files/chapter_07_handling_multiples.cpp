#include "splashkit.h"

const int MAX_MAP_ROWS = 20;
const int MAX_MAP_COLS = 20;

const int TILE_WIDTH = 60;
const int TILE_HEIGHT = 60;

enum explorer_state_kind
{
  PLAY_STATE,
};

enum tile_kind
{
  WATER_TILE,
  GRASS_TILE,
};

struct tile_data
{
  tile_kind kind;
};

struct map_data
{
  tile_data tiles[MAX_MAP_COLS][MAX_MAP_ROWS];
};

struct explorer_data
{
  map_data map;
  point_2d camera_position;
};

void init_map(map_data &map)
{
  for(int c = 0; c < MAX_MAP_COLS; c++)
  {
  }
}

void random_map(map_data &map)
{
  for(int c = 0; c < MAX_MAP_COLS; c++)
  {
  }
}

int main()
{
  open_window("Map Explorer", 800, 600);

  explorer_data data;
  init_explorer_data(data);
}
