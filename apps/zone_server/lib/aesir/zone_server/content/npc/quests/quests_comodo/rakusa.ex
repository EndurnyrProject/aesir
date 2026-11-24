defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsComodo.Rakusa do
  @moduledoc """
  Rakusa talks about Comodo and its legendary cheese.

  ## Behavior

  - Advances the doomed swords quest after discussing Magatu.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Evera
    - Samuray22
    - Brainstorm

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "comodo",
        x: 164,
        y: 291,
        dir: 4,
        sprite: 73,
        name: "Rakusa",
        scope: :shared,
        unique_name: "Rakusa#cmd"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      case get_char_var(ctx, :dmdswrd_Q, 0) do
        6 ->
          ctx
          |> mes("[Rakusa]")
          |> mes("See that guy sitting")
          |> mes("over there? All he does")
          |> mes("is talk about Comodo Cheese,")
          |> mes("just mumbling nonsense about")
          |> mes("its incredible flavors all day")
          |> mes("long. He's nuts, I tell you.")
          |> next()
          |> mes("[Rakusa]")
          |> mes("First of all, you need")
          |> mes("freakin' milk to make any")
          |> mes("cheese. You see any cows")
          |> mes("around here? Nope, I thought")
          |> mes("so! Still, I think he really")
          |> mes("believes that it exists...")
          |> set_char_var(:dmdswrd_Q, 7)

        7 ->
          ctx
          |> mes("[Rakusa]")
          |> mes("Damn it! I know for a fact")
          |> mes("that the idea of Comodo even")
          |> mes("having a cheese is crazy, but")
          |> mes("that guy's talking has gotten")
          |> mes("me curious now! Maybe it does")
          |> mes("exist? How would it even taste?")

        _ ->
          ctx
          |> mes("[Rakusa]")
          |> mes("You know, Comodo has")
          |> mes("a reputation for offering")
          |> mes("high class recreation, so")
          |> mes("people forget that we actually")
          |> mes("have two dangerous dungeons.")
          |> next()
          |> mes("[Rakusa]")
          |> mes("You adventurers need to")
          |> mes("be extra careful if you explore")
          |> mes("the caves--the monsters there")
          |> mes("are unusually strong. Make")
          |> mes("sure that you're well prepared")
          |> mes("before you even think of going!")
      end

    close(ctx)
  end
end
