defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.TempleEntrance do
  @moduledoc """
  Controls access to the Rachel temple.

  ## Behavior

  - Blocks unqualified visitors after the donation goal is reached.
  - Warps other visitors into the temple.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ra_temple",
        x: 119,
        y: 180,
        dir: 0,
        sprite: 45,
        name: "Temple Entrance",
        scope: :shared,
        unique_name: "Temple Entrance#ra_tem",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch", ctx) do
    enter(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    enter(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp enter(ctx) do
    if get_server_var(ctx, "rachel_donate", 0) >= 10_000 and
         not Rathena.truthy?(:erlang.band(get_char_var(ctx, :MISC_QUEST, 0), 8192)) and
         get_char_var(ctx, :ra_tem_q, 0) < 10 do
      {ctx, _} =
        ctx
        |> mes("^3355FFThe temple's")
        |> mes("entrance is locked.^000000")
        |> next()
        |> select(["Kick Door.", "Smash Door with Weapon."])

      ctx
      |> emotion(:huk, getnpcid(ctx, "Nemma#ra_temple"))
      |> mes("[Priestess Nemma]")
      |> mes("Please don't do that!")
      |> close()
    else
      warp(ctx, "ra_temin", 169, 23)
    end
  end
end
