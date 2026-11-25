defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.BossLghtBossAdmin do
  @moduledoc """
  An administrative NPC manages quest variables.

  ## Behavior

  - Displays or changes quest progress through a GM-only menu.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - The original read and wrote `lght_boss`, a misspelling of the President quest's
    `lhz_boss` progress variable that nothing else uses; it now reads and writes `lhz_boss`.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "sec_in02",
        x: 17,
        y: 170,
        dir: 4,
        sprite: 809,
        name: "boss",
        scope: :shared,
        unique_name: "lght_boss_admin"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FGmNpc
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FGmNpc.call(ctx, [])

    {ctx, choice} =
      ctx
      |> mes("[Patch]")
      |> mes("Tell me what you want.")
      |> next()
      |> select(["Current Variables", "How Many", "Shinokas - Quest Complete"])

    case choice do
      1 ->
        show_progress(ctx)

      2 ->
        {ctx, input} = input(ctx, :int)
        {_, value} = Rathena.input_int(input, 0, 1000)
        ctx = set_local(ctx, :input, value)
        ctx |> set_char_var(:lhz_boss, get_local(ctx, :input, 0)) |> show_progress()

      3 ->
        ctx |> set_char_var(:Shinokas_Quest, 11) |> close()

      _ ->
        ctx
    end
  end

  defp show_progress(ctx) do
    ctx = mes(ctx, " ")
    ctx |> mes(Rathena.concat("", get_char_var(ctx, :lhz_boss, 0))) |> close()
  end
end
