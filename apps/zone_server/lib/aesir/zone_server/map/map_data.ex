defmodule Aesir.ZoneServer.Map.MapData do
  @moduledoc """
  Map data structure holding map dimensions and cell information.
  Cells are stored as raw binary GAT types for maximum performance.
  """

  alias Aesir.ZoneServer.Map.GatType

  defstruct [
    :name,
    :index,
    :xs,
    :ys,
    :cells,
    :dynamic_cells,
    :npcs,
    :users,
    :instance_id,
    :zone
  ]

  @typedoc """
  name: The name of the map (e.g. "prontera.gat")
  index: Unique index for the map (for internal use)
  xs: Width of the map in cells
  ys: Height of the map in cells
  cells: Raw binary data representing GAT types for each cell
  dynamic_cells: Map of dynamic flags for each cell (e.g. NPCs, ice walls)
  npcs: List of NPCs on the map
  users: Number of users currently on the map
  instance_id: Optional instance ID if this map is part of an instance
  zone: Zone ID for the map (for zone management)
  """
  @type t :: %__MODULE__{
          name: String.t(),
          index: integer(),
          xs: integer(),
          ys: integer(),
          cells: binary(),
          dynamic_cells: map(),
          npcs: list(),
          users: integer(),
          instance_id: integer() | nil,
          zone: integer()
        }

  @doc """
  Creates a new map with the given dimensions.
  All cells are initialized as walkable ground.
  """
  @spec new(String.t(), integer(), integer()) :: t()
  def new(name, width, height) do
    cells = :binary.copy(<<GatType.walkable()>>, width * height)

    %__MODULE__{
      name: name,
      xs: width,
      ys: height,
      cells: cells,
      dynamic_cells: %{},
      npcs: [],
      users: 0,
      zone: 0
    }
  end

  @doc """
  Gets a cell GAT type at the given coordinates.
  Returns nil if coordinates are out of bounds.
  """
  @spec get_cell(t(), integer(), integer()) :: integer() | nil
  def get_cell(%__MODULE__{xs: xs, ys: ys, cells: cells}, x, y)
      when x >= 0 and x < xs and y >= 0 and y < ys do
    index = y * xs + x
    binary_part(cells, index, 1) |> :binary.first()
  end

  def get_cell(_, _, _), do: nil

  @doc """
  Sets a cell at the given coordinates.
  """
  @spec set_cell(t(), integer(), integer(), integer()) :: t()
  def set_cell(%__MODULE__{xs: xs, ys: ys, cells: cells} = map, x, y, gat_type)
      when x >= 0 and x < xs and y >= 0 and y < ys do
    index = y * xs + x
    <<prefix::binary-size(index), _::8, suffix::binary>> = cells
    new_cells = <<prefix::binary, gat_type::8, suffix::binary>>
    %{map | cells: new_cells}
  end

  def set_cell(map, _, _, _), do: map

  @doc """
  Checks if a position is walkable.
  """
  @spec walkable?(t(), integer(), integer()) :: boolean()
  def walkable?(map, x, y) do
    case get_cell(map, x, y) do
      nil -> false
      gat_type -> GatType.is_walkable?(gat_type)
    end
  end

  @doc """
  Checks if a position blocks projectiles.
  """
  @spec blocks_projectile?(t(), integer(), integer()) :: boolean()
  def blocks_projectile?(map, x, y) do
    case get_cell(map, x, y) do
      nil -> true
      gat_type -> GatType.blocks_projectile?(gat_type)
    end
  end

  @doc """
  Checks various cell properties.
  Based on rAthena's map_getcellp function.
  """
  @spec check_cell(t(), integer(), integer(), atom()) :: boolean() | integer()
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def check_cell(map, x, y, check_type) do
    gat_type = get_cell(map, x, y)
    dynamic = Map.get(map.dynamic_cells, y * map.xs + x, %{})

    case check_type do
      :get_type ->
        gat_type || GatType.wall()

      :chk_wall ->
        GatType.is_wall?(gat_type || 0)

      :chk_water ->
        GatType.is_water?(gat_type || 0)

      :chk_cliff ->
        GatType.is_cliff?(gat_type || 0)

      :chk_pass ->
        gat_type != nil and GatType.is_walkable?(gat_type) and not Map.get(dynamic, :npc, false)

      :chk_nopass ->
        gat_type == nil or not GatType.is_walkable?(gat_type) or Map.get(dynamic, :npc, false)

      :chk_reach ->
        gat_type != nil and not GatType.blocks_projectile?(gat_type) and
          not Map.get(dynamic, :icewall, false)

      :chk_noreach ->
        gat_type == nil or GatType.blocks_projectile?(gat_type) or
          Map.get(dynamic, :icewall, false)

      :chk_npc ->
        Map.get(dynamic, :npc, false)

      :chk_basilica ->
        Map.get(dynamic, :basilica, false)

      :chk_landprotector ->
        Map.get(dynamic, :landprotector, false)

      :chk_novending ->
        Map.get(dynamic, :novending, false)

      :chk_nochat ->
        Map.get(dynamic, :nochat, false)

      :chk_maelstrom ->
        Map.get(dynamic, :maelstrom, false)

      :chk_icewall ->
        Map.get(dynamic, :icewall, false)

      :chk_nobuyingstore ->
        Map.get(dynamic, :nobuyingstore, false)

      _ ->
        false
    end
  end

  @doc """
  Sets a dynamic flag on a cell.
  """
  @spec set_cell_flag(t(), integer(), integer(), atom(), boolean()) :: t()
  def set_cell_flag(%__MODULE__{xs: xs, ys: ys} = map, x, y, flag, value)
      when x >= 0 and x < xs and y >= 0 and y < ys do
    index = y * xs + x
    dynamic = Map.get(map.dynamic_cells, index, %{})

    updated_dynamic =
      if value do
        Map.put(dynamic, flag, value)
      else
        Map.delete(dynamic, flag)
      end

    new_dynamic_cells =
      if map_size(updated_dynamic) == 0 do
        Map.delete(map.dynamic_cells, index)
      else
        Map.put(map.dynamic_cells, index, updated_dynamic)
      end

    %{map | dynamic_cells: new_dynamic_cells}
  end

  def set_cell_flag(map, _, _, _, _), do: map

  @doc """
  Loads cells directly from binary GAT data.
  """
  @spec load_from_gat_binary(t(), binary()) :: t()
  def load_from_gat_binary(map, gat_binary) when byte_size(gat_binary) == map.xs * map.ys do
    %{map | cells: gat_binary}
  end

  def load_from_gat_binary(map, _), do: map
end
