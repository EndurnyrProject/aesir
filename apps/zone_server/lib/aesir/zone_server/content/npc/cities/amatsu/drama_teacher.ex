defmodule Aesir.ZoneServer.Content.Npc.Cities.Amatsu.DramaTeacher do
  @moduledoc """
  Recruits a potential actress for Amatsu's legendary White Dryad play.

  ## Behavior

  - Marks the tree conversation as the drama teacher's perspective.
  - Asks male visitors to recommend an actress and encourages female visitors to pursue acting.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "amatsu",
        x: 243,
        y: 202,
        dir: 3,
        sprite: 760,
        name: "Drama Teacher",
        scope: :shared,
        unique_name: "Drama Teacher#ama"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> set_char_var(:jap_tree, 2)
      |> mes("[Garakame sensei]")
      |> mes("This is a beautiful place")
      |> mes("with everlasting cherry blossoms.")
      |> mes("Also, this town is the origin of")
      |> mes("legendary play, 'White Dryad.' ")
      |> next()

    if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
      ask_for_actress(ctx)
    else
      encourage_actress(ctx)
    end
  end

  defp ask_for_actress(ctx) do
    ctx
    |> mes("[Garakame sensei]")
    |> mes("If you know a girl who is")
    |> mes("talented in acting, please")
    |> mes("bring her to me. I have been")
    |> mes("searching for a girl who could")
    |> mes("play the role as the 'White Dryad.'")
    |> next()
    |> mes("[Garakame sensei]")
    |> mes("The 'White Dryad' is a nymph of")
    |> mes("cherry tree... It has been hard to")
    |> mes("find a girl who can perform")
    |> mes("as the 'White Dryad...'")
    |> close()
  end

  defp encourage_actress(ctx) do
    ctx
    |> emotion(:surprise)
    |> mes("[Garakame sensei]")
    |> mes("Are you interested in acting?")
    |> mes("I need someone who sees")
    |> mes("the passion in acting and")
    |> mes("can understand my vision.")
    |> next()
    |> mes("[Garakame sensei]")
    |> mes("When you stand on the stage,")
    |> mes("you need to become the")
    |> mes("character. Your acting needs")
    |> mes("to touch the hearts of the")
    |> mes("audience and touch their souls.")
    |> next()
    |> mes("[Garakame sensei]")
    |> mes("Everyone's life is like a ")
    |> mes("drama, right? Enjoy your life")
    |> mes("as what you are and find me")
    |> mes("someday when you are ready.")
    |> close()
  end
end
