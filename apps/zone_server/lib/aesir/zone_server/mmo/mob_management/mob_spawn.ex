defmodule Aesir.ZoneServer.Mmo.MobManagement.MobSpawn do
  @moduledoc """
  Mob spawn configuration: where and how mobs spawn on a map.

  `boss` marks a `boss_monster` spawn line: only such a line rolls its
  `respawn_variance`, and its pending respawn deadline is persisted.
  """

  use TypedStruct

  defmodule SpawnArea do
    @moduledoc false

    use TypedStruct

    typedstruct do
      @typedoc """
      `x` and `y` locate the center; `{0, 0}` means anywhere on the map.
      `xs` and `ys` are the radii; both zero means the exact cell.
      """
      field :x, integer(), enforce: true
      field :y, integer(), enforce: true
      field :xs, integer(), default: 0
      field :ys, integer(), default: 0
    end
  end

  typedstruct do
    @typedoc "A spawn line for a single monster type."
    field :mob, integer(), enforce: true
    field :amount, integer(), enforce: true
    field :respawn_time, integer(), enforce: true
    field :respawn_variance, integer(), default: 0
    field :boss, boolean(), default: false
    field :spawn_area, SpawnArea.t(), enforce: true
    field :summoned, boolean(), default: false
  end
end
