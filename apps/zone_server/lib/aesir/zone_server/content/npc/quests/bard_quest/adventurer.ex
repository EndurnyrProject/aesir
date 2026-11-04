defmodule Aesir.ZoneServer.Content.Npc.Quests.BardQuest.Adventurer do
  @moduledoc """
  Pane greets adventurers while working on his report.

  ## Behavior

  - Reacts differently to female adventurers and compares their answer with their name.

  ## Credits

  - Original from rAthena, authors Riotblade and L0ne_W0lf; contributors Lupus, SinSloth, and Euphy.

  ## Adaptation

  - Transpiled by `mix aesir.import.npcs` from rAthena script.
  - LLM-assisted Elixir refactor.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_in04",
        x: 33,
        y: 119,
        dir: 3,
        sprite: 828,
        name: "Adventurer",
        scope: :shared,
        unique_name: "Adventurer#1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("...")
      |> next()
      |> mes("...")
      |> mes(".......")
      |> next()
      |> mes("^3355FF*Scribble Scribble*^000000")
      |> next()
      |> mes("[Energetic Young Man]")
      |> mes("Err...?")
      |> mes("What is it?")
      |> next()

    if sex(ctx) == get_char_var(ctx, :SEX_FEMALE, 0) do
      ctx =
        ctx
        |> emotion(:smile)
        |> mes("[Energetic Young Man]")
        |> mes("Oh...!")
        |> mes("A beautiful,")
        |> mes("young lady~!")
        |> next()
        |> mes("[Energetic Young Man]")
        |> mes("Hello there~")
        |> mes("My name is Pane.")
        |> mes("May I ask yours?")

      {ctx, entered_name} = ctx |> set_temp_var(:"name$", char_name(ctx, 0)) |> input(:string)

      ctx =
        ctx
        |> set_local(:"inputstr$", entered_name)
        |> next()
        |> mes("[Energetic Young Man]")
        |> mes("Oh...")

      ctx = mes(ctx, Rathena.concat(Rathena.concat("", get_local(ctx, :"inputstr$", "")), "..."))

      if get_temp_var(ctx, :"name$", "") == get_local(ctx, :"inputstr$", "") do
        ctx = ctx |> next() |> mes("[Energetic Young Man]")

        ctx
        |> mes(Rathena.concat(Rathena.concat("^FF6699", get_local(ctx, :"inputstr$", "")), "!"))
        |> mes("Such a wonderful name!")
        |> next()
        |> mes("[Energetic Young Man]")
        |> mes(
          "I shall remember your name, my lady. Oh, but I'm so sorry. I'm kind of busy right now. Would you come back later? I'll do my best to please you next time."
        )
        |> emotion(:chup)
        |> close()
      else
        ctx
        |> mes("That's your name?")
        |> next()
        |> mes("[Energetic Young Man]")
        |> mes(
          "Eh, whatever. Oh, but I'm so sorry. I'm kind of busy right now. Would you come back later? I'll do my best to please you next time."
        )
        |> emotion(:smile)
        |> close()
      end
    else
      ctx
      |> mes("[Energetic Young Man]")
      |> mes("What, man...!")
      |> mes("Leave me alone.")
      |> mes("Can't you see I'm busy?")
      |> close()
    end
  end
end
