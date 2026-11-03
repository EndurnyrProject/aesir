defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.RogueSkills.Killer do
  @moduledoc """
  The thief who steals Chae Takbae's skill book, used for Close Confine practice.

  ## Behavior

  - Starts hidden and appears when the Rogue Guild alerts the player to the theft.
  - On the chase step, touching him casts Close Confine and runs ten movement-prediction drills
    before the book is recovered and he disappears.
  - Touching him again after the recovery only shows that he is still confined.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - 2Spiritual Kid
    - DracoRPG
    - L0ne_W0lf
    - Samuray22
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "in_rogue",
        x: 357,
        y: 174,
        dir: 2,
        sprite: 705,
        name: "Killer",
        scope: :shared,
        unique_name: "Killer#Rogueguild",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx) do
    disablenpc(ctx, "Killer#Rogueguild")
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTouch_", ctx) do
    case get_char_var(ctx, :ROG_SK, 0) do
      10 -> confine(ctx)
      11 -> still_confined(ctx)
      _ -> ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp confine(ctx) do
    ctx =
      ctx
      |> specialeffect2(:changecold)
      |> specialeffect(:changewind)
      |> specialeffect2(:lightsphere)
      |> set_char_var(:ROG_SK, 11)
      |> mes("[Killer]")
      |> mes("Wh-what have")
      |> mes("you done to me?!")
      |> mes("C-can't... move!")
      |> next()
      |> mes("[Haijara Greg]")
      |> mes("Oh? I didn't expect")
      |> mes("you to be able to cast")
      |> mes("Close Confine so soon!")
      |> mes("Amazing, just amazing!")
      |> mes("Now, this is a good chance")
      |> mes("for you to master the skill...")
      |> next()
      |> mes("[Haijara Greg]")
      |> mes("Now pay attention.")
      |> mes("I want you to practice")
      |> mes("predicting your opponent's")
      |> mes("movement intent on this killer.")
      |> mes("You should be able to see which way he plans to move by his aura.")
      |> next()
      |> mes("[Haijara Greg]")
      |> mes("If he plans to move to left,")
      |> mes("his aura will be white. If he")
      |> mes("moves to the right, it will be")
      |> mes("yellow. If he intends to go")
      |> mes("backward, it will be pale red.")
      |> next()

    auras = {
      get_char_var(ctx, :EF_CHANGECOLD, 0),
      get_char_var(ctx, :EF_CHANGEWIND, 0),
      get_char_var(ctx, :EF_CHANGEEARTH, 0)
    }

    1..10
    |> Enum.reduce(ctx, fn _, ctx -> predict_move(ctx, auras) end)
    |> mes("^3355FFYou successfully")
    |> mes("retrieved the priceless")
    |> mes("skill book written by the")
    |> mes("legendary Chae Takbae.^000000")
    |> close()
    |> hide_killer()
  end

  defp predict_move(ctx, auras) do
    move = Enum.random(1..3)

    {ctx, choice} =
      ctx
      |> specialeffect(elem(auras, move - 1))
      |> select(["Block him to the Left", "Block him to the Right", "Block his Retreat"])

    ctx =
      if choice == move do
        ctx
        |> mes("^3355FFThe killer remains")
        |> mes("unable to move and looks")
        |> mes("incredibly confused! Right")
        |> mes("now, you're using the Close")
        |> mes("Confine skill perfectly!^000000")
        |> specialeffect(:potion1)
        |> specialeffect2(:potion7)
      else
        ctx
        |> mes("^3355FFWait--!")
        |> mes("For some reason,")
        |> mes("you sense that's not")
        |> mes("the direction the killer")
        |> mes("is moving at this moment.")
        |> mes("You naturally correct yourself.^000000")
      end

    next(ctx)
  end

  defp still_confined(ctx) do
    ctx
    |> mes("[Killer]")
    |> mes("Grrrrr...")
    |> mes("S-still...")
    |> mes("C-can't... Move!")
    |> close()
    |> hide_killer()
  end

  defp hide_killer(ctx) do
    ctx |> disablenpc("Killer#Rogueguild") |> donpcevent("#killershow01::OnDisable")
  end
end
