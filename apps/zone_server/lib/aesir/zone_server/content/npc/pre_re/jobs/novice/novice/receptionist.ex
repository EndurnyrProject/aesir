defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.Novice.Novice.Receptionist do
  @moduledoc """
  Registers pre-renewal novices for training or sends them directly to a town.

  ## Behavior

  - Verifies the character name supplied by the trainee.
  - Explains the courses and offers training registration or direct town travel.
  - Clears novice course progress and chooses a random town when training is skipped.

  ## Credits

  - Original from rAthena, authors: Dr.Evil and MasterOfMuppets.
  - Elixir adaptation: transpiled and refactored by an LLM.
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "new_1-2",
        x: 100,
        y: 29,
        dir: 4,
        sprite: 86,
        name: "Receptionist",
        unique_name: "Receptionist#nv1"
      },
      %{
        map: "new_2-2",
        x: 100,
        y: 29,
        dir: 4,
        sprite: 86,
        name: "Receptionist",
        unique_name: "Receptionist#nv2"
      },
      %{
        map: "new_3-2",
        x: 100,
        y: 29,
        dir: 4,
        sprite: 86,
        name: "Receptionist",
        unique_name: "Receptionist#nv3"
      },
      %{
        map: "new_4-2",
        x: 100,
        y: 29,
        dir: 4,
        sprite: 86,
        name: "Receptionist",
        unique_name: "Receptionist#nv4"
      },
      %{
        map: "new_5-2",
        x: 100,
        y: 29,
        dir: 4,
        sprite: 86,
        name: "Receptionist",
        unique_name: "Receptionist#nv5"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, name} =
      ctx
      |> mes("[Training Grounds Receptionist]")
      |> mes("Hello, you look to be new here.")
      |> mes("What is your name?")
      |> next()
      |> input(:string)

    if name == char_name(ctx, 0) do
      welcome(ctx)
    else
      ctx
      |> mes("[Training Grounds Receptionist]")
      |> mes("Sorry, but I don't think I heard")
      |> mes("you correctly")
      |> close()
    end
  end

  defp welcome(ctx) do
    ctx
    |> mes("[Training Grounds Receptionist]")
    |> mes("Welcome!")
    |> mes("You are at the entrance")
    |> mes("of the ^3355FFTraining Grounds^000000.")
    |> next()
    |> mes("[Training Grounds Receptionist]")
    |> mes("If you're new")
    |> mes("to the Ragnarok world,")
    |> mes("please choose the")
    |> mes("^3355FFTraining Grounds Introduction^000000")
    |> mes("menu for more information.")
    |> next()
    |> training_menu()
  end

  defp training_menu(ctx) do
    {ctx, choice} =
      select(ctx, [
        "Apply for training.",
        "Direct access to Ragnarok Online.",
        "^3355FFTraining Grounds Introduction.^000000",
        "I need a moment to think."
      ])

    choose_training(ctx, choice)
  end

  defp choose_training(ctx, 1) do
    ctx
    |> mes("[Training Grounds Receptionist]")
    |> mes(
      "Thank you for applying for Novice training. For detailed information of each training course, please inquire the Guides for assistance."
    )
    |> next()
    |> mes("[Training Grounds Receptionist]")
    |> mes(
      "When you have questions about the training course process, please feel free to ask any of the Tutors."
    )
    |> next()
    |> mes("[Training Grounds Receptionist]")
    |> mes("You will now be transferred")
    |> mes("to the Training Grounds.")
    |> close()
    |> warp("new_1-2", 100, 70)
  end

  defp choose_training(ctx, 2) do
    ctx
    |> mes("[Training Grounds Receptionist]")
    |> mes("I understand.")
    |> mes("Please do your")
    |> mes("best, and I wish you")
    |> mes("the best of luck!")
    |> close()
    |> set_char_var(:nov_1st_cos, 0)
    |> set_char_var(:nov_2nd_cos, 0)
    |> set_char_var(:nov_3_swordman, 0)
    |> set_char_var(:nov_3_archer, 0)
    |> set_char_var(:nov_3_thief, 0)
    |> set_char_var(:nov_3_magician, 0)
    |> set_char_var(:nov_3_acolyte, 0)
    |> set_char_var(:nov_3_merchant, 0)
    |> depart()
  end

  defp choose_training(ctx, 3) do
    ctx
    |> mes("[Training Grounds Receptionist]")
    |> mes(
      "This training grounds was established in order to provide useful information to new players of Ragnarok Online by the Rune-Midgarts Kingdom's Board of Education."
    )
    |> next()
    |> mes("[Training Grounds Receptionist]")
    |> mes(
      "The training course is organized into two parts: the Basic Knowledge classes, and Field Combat training."
    )
    |> next()
    |> mes("[Training Grounds Receptionist]")
    |> mes(
      "Through the first course, players will learn the necessary knowledge for a smoother gaming experience."
    )
    |> next()
    |> mes("[Training Grounds Receptionist]")
    |> mes("In Field Combat Training,")
    |> mes(
      "players will engage in actual battle with weak monsters so they can learn the basics of fighting."
    )
    |> next()
    |> mes("[Training Grounds Receptionist]")
    |> mes("With this battle practice,")
    |> mes("players will be able to gain more experience before they enter the real world.")
    |> next()
    |> mes("[Training Grounds Receptionist]")
    |> mes(
      "At the end of the training, we will provide an introduction to the 1st Job Classes. This will help players decide which job class is best for them."
    )
    |> next()
    |> mes("[Training Grounds Receptionist]")
    |> mes(
      "If you wish to participate in the training grounds, please choose '^3355FFApply for training^000000' in the menu."
    )
    |> next()
    |> mes("[Training Grounds Receptionist]")
    |> mes(
      "Otherwise, if you want to skip the basic training and immediately enter the world of Ragnarok Online, please choose '^3355FFDirect access to Ragnarok Online^000000.'"
    )
    |> next()
    |> training_menu()
  end

  defp choose_training(ctx, 4) do
    ctx
    |> mes("[Training Grounds Receptionist]")
    |> mes("I understand.")
    |> mes("Please, take your time.")
    |> close()
  end

  defp choose_training(ctx, _choice), do: training_menu(ctx)

  defp depart(ctx) do
    towns = [
      {"prontera", 273, 354},
      {"morocc", 160, 94},
      {"geffen", 120, 100},
      {"payon", 70, 100},
      {"alberta", 116, 57},
      {"izlude", 94, 103}
    ]

    {map, x, y} = Enum.at(towns, :rand.uniform(6) - 1)
    ctx |> savepoint(map, x, y) |> warp(map, x, y)
  end
end
