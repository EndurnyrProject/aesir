defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.MysteriousEnergy26832 do
  @moduledoc """
  Interacts with a mysterious seal during The Sign quest.

  ## Behavior

  - Attempts to break the seal at the relevant quest stages and advances progress.
  - Describes the mysterious energy otherwise.

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

  alias Aesir.ZoneServer.Content.Npc.Functions.FSignseal
  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "gl_dun02",
        x: 268,
        y: 32,
        dir: 0,
        sprite: 111,
        name: "Mysterious Energy",
        scope: :shared,
        unique_name: "Mysterious Energy#3"
      }
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    ctx = set_local(ctx, :crash_s, Enum.random(1..1000))

    case get_char_var(ctx, :sign_q, 0) do
      stage when stage in [103, 105, 108] ->
        {ctx, _} = FSignseal.call(ctx, [get_local(ctx, :crash_s, 0)])

        ctx =
          case get_char_var(ctx, :sign_q, 0) do
            103 -> set_char_var(ctx, :sign_q, 107)
            105 -> set_char_var(ctx, :sign_q, 109)
            108 -> set_char_var(ctx, :sign_q, 112)
            _ -> ctx
          end

        close(ctx)

      _ ->
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
