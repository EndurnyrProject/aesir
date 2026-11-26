defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.MysteriousEnergy do
  @moduledoc """
  Reveals a mysterious seal during The Sign quest.

  ## Behavior

  - Attempts to break the seal at the appropriate quest stage and advances progression.
  - Otherwise describes the mysterious energy.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "gl_dun02",
        x: 262,
        y: 265,
        dir: 0,
        sprite: 111,
        name: "Mysterious Energy",
        scope: :shared,
        unique_name: "Mysterious Energy#1"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FSignseal
  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    ctx = set_local(ctx, :crash_s, Enum.random(1..1000))

    if get_char_var(ctx, :sign_q, 0) == 101 do
      {ctx, _} = FSignseal.call(ctx, [get_local(ctx, :crash_s, 0)])

      ctx
      |> set_char_var(:sign_q, 105)
      |> close()
    else
      ctx
      |> mes("^3355FFYou sense a strange,")
      |> mes(
        "mysterious energy emanating from this area. For some reason, this power strikes you with a faint feeling of sadness.^000000"
      )
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
