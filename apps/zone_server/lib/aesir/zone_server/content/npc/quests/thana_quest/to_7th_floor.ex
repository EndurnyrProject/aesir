defmodule Aesir.ZoneServer.Content.Npc.Quests.ThanaQuest.To7thFloor do
  @moduledoc """
  Controls access to the seventh floor.

  ## Behavior

  - Eligible adventurers exchange a black key for a gem and enter the portal.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "tha_t06",
        x: 119,
        y: 120,
        dir: 0,
        sprite: 45,
        name: "to 7th Floor",
        scope: :shared,
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ctx
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp ev_ontouch(ctx) do
    if eligible?(ctx) do
      portal(ctx)
    else
      ctx |> mes("A mysterious power is blocking my path.") |> close()
    end
  end

  defp eligible?(ctx) do
    Rathena.truthy?(:erlang.band(eaclass(ctx), :erlang.bor(768, 1_048_576))) or
      Rathena.truthy?(:erlang.band(eaclass(ctx), 4096)) or
      ((Rathena.job_id(class(ctx)) == Rathena.job_id(:super_novice) or
          Rathena.job_id(class(ctx)) == Rathena.job_id(:taekwon) or
          Rathena.job_id(class(ctx)) == Rathena.job_id(:star_gladiator) or
          Rathena.job_id(class(ctx)) == Rathena.job_id(:soul_linker) or
          Rathena.job_id(base_class(ctx)) == Rathena.job_id(:ninja) or
          Rathena.job_id(class(ctx)) == Rathena.job_id(:gunslinger) or
          Rathena.job_id(class(ctx)) == Rathena.job_id(:summoner)) and base_level(ctx) > 94)
  end

  defp portal(ctx) do
    has_key = count_item(ctx, 7425) > 0

    ctx =
      ctx
      |> mes("The shadow of a Black Key is gleaming in the center of the portal.")
      |> mes("To pass this way, looks like I need something.")

    if has_key do
      ctx
      |> next()
      |> mes("The Black Key reacts to the portal and floats in the air.")
      |> next()
      |> mes("The key seems to separate into many particles and suddenly collapses into a ball.")
      |> mes("The barricade is removed through the power from newly formed black magic gem.")
      |> close2()
      |> delitem(7425, 1)
      |> give_item(7430, 1)
      |> warp("thana_step", 69, 369)
    else
      close(ctx)
    end
  end
end
