defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsComodo.BbqPapa do
  @moduledoc """
  A family discusses a rumored witch over barbecue.

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
        x: 216,
        y: 310,
        dir: 4,
        sprite: 50,
        name: "BBQ Papa",
        scope: :shared,
        unique_name: "CmdFamily"
      },
      %{
        map: "comodo",
        x: 215,
        y: 307,
        dir: 4,
        sprite: 74,
        name: "BBQ Mama",
        scope: :shared,
        unique_name: "BBQ Mama#cmd"
      },
      %{
        map: "comodo",
        x: 213,
        y: 310,
        dir: 4,
        sprite: 706,
        name: "BBQ Boy",
        scope: :shared,
        unique_name: "BBQ Boy#cmd2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[BBQ Boy]")
    |> mes("D-daddy! Is what those")
    |> mes("people talking about true?")
    |> mes("Was there really an evil")
    |> mes("witch here in our village?")
    |> next()
    |> mes("[BBQ Mama]")
    |> mes("Honey...")
    |> mes("I'm sure those")
    |> mes("good people were")
    |> mes("just kidding around~")
    |> mes("How can that be true?")
    |> next()
    |> mes("[BBQ Papa]")
    |> mes("Now, now, don't tell")
    |> mes("me my little man is afraid")
    |> mes("of something like a little")
    |> mes("witch. It's just an old fairy")
    |> mes("tale, son: no reason to")
    |> mes("feel frightened at all.")
    |> next()
    |> mes("[BBQ Boy]")
    |> mes("No, Daddy, I'm not")
    |> mes("scared! But if the witch")
    |> mes("really lived here, then her")
    |> mes("home is somewhere around")
    |> mes("here in Comodo, right? I'm")
    |> mes("gonna go find it someday!")
    |> next()
    |> mes("[BBQ Mama]")
    |> mes("Oh, but I'm sure our")
    |> mes("Chief would already know")
    |> mes("something about that witch")
    |> mes("if she truly exists. Anyway,")
    |> mes("let's hurry and eat before")
    |> mes("the barbeque burns, okay?")
    |> next()
    |> mes("[BBQ Boy]")
    |> mes("Yay, barbeque!")
    |> mes("Mmmmm... Someday,")
    |> mes("if that witch is real,")
    |> mes("I'm gonna find out")
    |> mes("all about her!")
    |> close()
  end
end
