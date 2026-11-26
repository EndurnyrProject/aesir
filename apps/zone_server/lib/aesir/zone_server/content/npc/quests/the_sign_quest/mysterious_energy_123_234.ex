defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.MysteriousEnergy123234 do
  @moduledoc """
  Reveals a mysterious seal during The Sign quest.

  ## Behavior

  - Attempts to break the seal at the appropriate quest stages and may advance progression.
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
        x: 123,
        y: 234,
        dir: 0,
        sprite: 111,
        name: "Mysterious Energy",
        scope: :shared,
        unique_name: "Mysterious Energy#6"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FSignseal
  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    ctx = set_local(ctx, :crash_s, Enum.random(1..1000))

    cond do
      get_char_var(ctx, :sign_q, 0) == 107 ->
        {ctx, _} = FSignseal.call(ctx, [get_local(ctx, :crash_s, 0)])

        ctx =
          if get_char_var(ctx, :sign_q, 0) == 107 do
            set_char_var(ctx, :sign_q, 111)
          else
            ctx
          end

        close(ctx)

      get_char_var(ctx, :sign_q, 0) == 116 ->
        {ctx, _} = FSignseal.call(ctx, [get_local(ctx, :crash_s, 0), 1])
        close(ctx)

      true ->
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
