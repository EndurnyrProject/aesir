defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.BardSkills.Yhelle85203 do
  @moduledoc """
  Yhelle the hen at her third Niflheim roost, where Bards gather her eggs for the Pang Voice
  skill quest.

  ## Behavior

  - Talking startles her: she leaves this roost and reappears at roost 4.
  - Walking into her runs `F_BardSkillYhelle`, which moves her on to roost 4 and may leave
    an Egg for a Bard who is still collecting them.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - L0ne_W0lf
    - DracoRPG

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
    quests/skills/bard_skills.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "niflheim",
        x: 85,
        y: 203,
        dir: 5,
        sprite: 800,
        name: "Yhelle",
        scope: :shared,
        unique_name: "Yhelle#bard_chick3",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FBardskillyhelle
  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnEnable", ctx) do
    enablenpc(ctx, "Yhelle#bard_chick3")
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnDisable", ctx) do
    disablenpc(ctx, "Yhelle#bard_chick3")
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTouch", ctx) do
    {ctx, _} = FBardskillyhelle.call(ctx, [3, 4])
    close(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> emotion(:huk)
    |> emotion(:huk)
    |> mes("[Hen Yhelle]")
    |> mes("Cluck-Cluuuck?")
    |> mes("Cluck cluck cluck!")
    |> next()
    |> disablenpc("Yhelle#bard_chick3")
    |> donpcevent("Yhelle#bard_chick4::OnEnable")
    |> mes("^3355FFUpon sensing your")
    |> mes("presense, the hen")
    |> mes("quickly ran away.^000000")
    |> close()
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
