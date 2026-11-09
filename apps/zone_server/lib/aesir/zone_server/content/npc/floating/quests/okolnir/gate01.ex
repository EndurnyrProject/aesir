defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.Gate01 do
  @moduledoc """
  The Okolnir castle gate that walks a challenger to the next room of the mirror
  challenge and spawns the room's gate mob.

  ## Behavior

  - Turning the gate on opens it and blocks the cell row in front of it; turning
    it off closes it again and clears every mob on the castle map.
  - Touching the gate refuses entry while 21 or more players stand on the castle
    map, and otherwise teleports the challenger to one of five random waiting
    spots when the castle's expected and recorded kill counts match.
  - The gate then spawns the next room's gate mob, choosing it by the challenger's
    first job class, records the room as reached and warps the challenger inside.
  - Starts disabled.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Joseph
    - L0ne_W0lf
    - Toshiro90
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/okolnir.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_qaru01",
        x: 346,
        y: 81,
        dir: 0,
        sprite: 45,
        name: "Gate01",
        scope: :shared,
        unique_name: "Gate01#gq_aru01",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru02",
        x: 346,
        y: 81,
        dir: 0,
        sprite: 45,
        name: "Gate01",
        scope: :shared,
        unique_name: "Gate01#gq_aru02",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru03",
        x: 346,
        y: 81,
        dir: 0,
        sprite: 45,
        name: "Gate01",
        scope: :shared,
        unique_name: "Gate01#gq_aru03",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru04",
        x: 346,
        y: 81,
        dir: 0,
        sprite: 45,
        name: "Gate01",
        scope: :shared,
        unique_name: "Gate01#gq_aru04",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru05",
        x: 346,
        y: 81,
        dir: 0,
        sprite: 45,
        name: "Gate01",
        scope: :shared,
        unique_name: "Gate01#gq_aru05",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch01",
        x: 346,
        y: 81,
        dir: 0,
        sprite: 45,
        name: "Gate01",
        scope: :shared,
        unique_name: "Gate01#gq_sch01",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch02",
        x: 346,
        y: 81,
        dir: 0,
        sprite: 45,
        name: "Gate01",
        scope: :shared,
        unique_name: "Gate01#gq_sch02",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch03",
        x: 346,
        y: 81,
        dir: 0,
        sprite: 45,
        name: "Gate01",
        scope: :shared,
        unique_name: "Gate01#gq_sch03",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch04",
        x: 346,
        y: 81,
        dir: 0,
        sprite: 45,
        name: "Gate01",
        scope: :shared,
        unique_name: "Gate01#gq_sch04",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch05",
        x: 346,
        y: 81,
        dir: 0,
        sprite: 45,
        name: "Gate01",
        scope: :shared,
        unique_name: "Gate01#gq_sch05",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FOkolnir
  alias Aesir.ZoneServer.Script.Ctx

  @max_challengers 21

  @rooms %{
    0 => [77, 271, 72, 271, 1],
    1 => [63, 278, 63, 282, 2],
    2 => [63, 294, 59, 294, 3],
    3 => [50, 300, 46, 300, 4],
    4 => [51, 280, 51, 285, 5],
    5 => [51, 258, 51, 262, 6],
    6 => [49, 243, 45, 243, 7],
    7 => [86, 249, 82, 249, 8],
    8 => [102, 243, 102, 248, 9],
    9 => [90, 256, 90, 260, 10],
    10 => [90, 283, 90, 280, 11],
    11 => [102, 295, 102, 300, 12],
    12 => [96, 285, 96, 290, 13],
    13 => [63, 278, 63, 282, 14],
    14 => [65, 243, 61, 243, 15],
    15 => [73, 249, 70, 249, 16],
    16 => [102, 275, 102, 282, 17],
    17 => [70, 300, 66, 300, 18],
    18 => [57, 255, 57, 258, 19],
    19 => [84, 277, 84, 280, 20]
  }

  @waiting_spots %{
    1 => {72, 271},
    2 => {45, 243},
    3 => {102, 248},
    4 => {102, 300},
    5 => {46, 300}
  }

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, _castle} = FOkolnir.call(ctx, [])
    ctx
  end

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    {ctx, castle} = FOkolnir.call(ctx, [])

    cond do
      getmapusers(ctx, castle_map(castle)) >= @max_challengers ->
        ctx
        |> mes("There are too many people, you can't enter.")
        |> close()

      getd(ctx, progress_var(castle)) == getd(ctx, challengers_var(castle)) ->
        {x, y} = Map.fetch!(@waiting_spots, :rand.uniform(5))
        warp(ctx, castle_map(castle), x, y)

      true ->
        room = Map.get(@rooms, getd(ctx, progress_var(castle)), [])

        ctx
        |> summon_gate_mob(castle, Enum.at(room, 0, 0), Enum.at(room, 1, 0))
        |> setd(progress_var(castle), Enum.at(room, 4, 0))
        |> warp(castle_map(castle), Enum.at(room, 2, 0), Enum.at(room, 3, 0))
    end
  end

  def on_event("OnEnable", ctx) do
    {ctx, castle} = FOkolnir.call(ctx, [])
    map = castle_map(castle)

    ctx
    |> enablenpc(gate_name(castle))
    |> setcell(map, 58, 302, 63, 302, :walkable, 0)
    |> setcell(map, 58, 302, 63, 302, :shootable, 0)
  end

  def on_event("OnDisable", ctx) do
    {ctx, castle} = FOkolnir.call(ctx, [])

    ctx
    |> disablenpc(gate_name(castle))
    |> killmonsterall(castle_map(castle))
  end

  def on_event("OnInit", ctx) do
    {ctx, castle} = FOkolnir.call(ctx, [])
    disablenpc(ctx, gate_name(castle))
  end

  defp summon_gate_mob(ctx, castle, x, y) do
    summon_mob(ctx,
      mob_id: gate_mob_id(ctx),
      map: castle_map(castle),
      at: {x, y},
      event: "#Gate_manager_#{castle}::OnMyMobDead"
    )
  end

  # rAthena `SMonster`: the mirror's gate mob is the challenger's own class line.
  defp gate_mob_id(ctx) do
    case base_class(ctx) do
      :mage -> 1663
      :archer -> 1662
      :acolyte -> 1661
      :merchant -> 1660
      :thief -> 1659
      _swordman_or_other -> 1652
    end
  end

  defp gate_name(castle), do: "Gate01#gq_#{castle}"
  defp castle_map(castle), do: "que_q#{castle}"

  # The reference keeps the room reached and the gate kills in one variable, and the
  # challenger count in its sibling.
  defp progress_var(castle), do: "$@gqse_#{castle}_miro"
  defp challengers_var(castle), do: "$@gqse_#{castle}_pcc"
end
