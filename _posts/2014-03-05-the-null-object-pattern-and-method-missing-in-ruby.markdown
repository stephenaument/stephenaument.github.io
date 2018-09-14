---
layout: post
title: "The Null Object Pattern and method_missing in Ruby"
date: 2014-03-05 23:01:09 -0600
comments: true
categories:
  - Design Patterns
  - Metaprogramming
image:
  credit: Photo by Braydon Anderson on Unsplash
  feature: /assets/images/hero/braydon-anderson-105552-unsplash.jpg
  topPosition: -420px
bgContrast: dark
bgGradientOpacity: darker
syntaxHighlighter: no
author:
  name: Step Aument
---

I encountered an interesting problem this week that allowed me to dig into the
Null Object pattern, Ruby duck typing, and Ruby's method_missing.

In our app we have a {% ihighlight ruby %}Duck{% endihighlight %} class (name changed to protect the innocent). Most
of our users have a {% ihighlight ruby %}Duck{% endihighlight %} associated with their account, but some don't. In
our application, we have certain situations which expect a Duck, even if the
user doesn't have one. If we don't have a Duck, but our app expects one and
passes it a message like {% ihighlight ruby %}quack,{% endihighlight %} we will receive an ugly `NoMethodError:
undefined method 'quack' for nil:NilClass` error.

How can we solve this without spreading smelly nil checks around our system? It
turns out there is an existing design pattern for just this situation, the Null
Object pattern. In the Null Object pattern, we create a stand in object for our
{% ihighlight ruby %}Duck{% endihighlight %} that can respond to the same interface, but without returning any
values. We avoid ugly {% ihighlight ruby %}NoMethodError{% endihighlight %}s without having to check for the objects
existence everywhere.

Here is our Duck:

{% highlight ruby linedivs %}
class Duck < ActiveRecord::Base
  def awake?
    status == 'awake'
  end

  def quack
    puts quack_style
  end
end
{% endhighlight %}

This is a Ruby on Rails ActiveRecord model, so there is more to it than we see
here. Here is the database migration file:

{% highlight ruby linedivs %}
class CreateDucks < ActiveRecord::Migration
  def change
    t.string name
    t.string status
    t.integer hunger
    t.string quack_style
    t.string color
    t.migratory boolean
  end
end
{% endhighlight %}

For each of these fields, ActiveRecord will create getter and setter methods in
the background. But for the {% ihighlight ruby %}migratory{% endihighlight %} boolean field, we will get the bonus
{% ihighlight ruby %}migratory?{% endihighlight %} predicate method.

In our case, it turned out that we need our {% ihighlight ruby %}NilDuck{% endihighlight %} to return *some* values,
but most things should just return {% ihighlight ruby %}nil{% endihighlight %}. The simplest way for us to implement
our {% ihighlight ruby %}NilDuck{% endihighlight %}, and the state in which I found my {% ihighlight ruby %}NilDuck{% endihighlight %} code this week looks
something like the following:

{% highlight ruby linedivs %}
class NilDuck
  attr_writer :name, :status, :hunger, :quack_style, :color, :migratory

  def name
    'Demo Duck'
  end

  def status
    'sleeping'
  end

  def hunger
    nil
  end

  def quack
  end

  def quack_style
    nil
  end

  def color
    'gray'
  end

  def awake?
    false
  end

  def migratory
    nil
  end

  def migratory?
    true
  end
end
{% endhighlight %}

Here we have provided the attribute setters our fake object needs with the
{% ihighlight ruby %}attr_writer{% endihighlight %} call. We then proceed to override each getter as needed. There
are a few special cases in which a value other than nil is desired, but the
default return value for our {% ihighlight ruby %}NilDuck{% endihighlight %} is {% ihighlight ruby %}nil{% endihighlight %}. In the cases in which we don't
have an actual {% ihighlight ruby %}Duck{% endihighlight %} and need to use a demo {% ihighlight ruby %}Duck{% endihighlight %}, we can pass in an instance
of our {% ihighlight ruby %}NilDuck{% endihighlight %} and everything will work as expected.

>Note: since Ruby is not a strongly typed language, we don't have to subclass
>our {% ihighlight ruby %}Duck{% endihighlight %} here or implement a formal common interface as we would in a
>strongly-typed language like Java. In Rubyland, types are determined by the
>public interface of the object in question. So if our {% ihighlight ruby %}NilDuck{% endihighlight %}, or any other
>object for that matter, implements the methods our client object calls in
>{% ihighlight ruby %}Duck{% endihighlight %}, we can substitute it. This is often called "duck typing," since if an
>object quacks like a duck, and acts like a duck, we can usually consider it a
>duck. We *do* implement a common interface, but the interface that we
>implement is conceptual, represented by the messages to which we expect our
>duck to respond. It's not baked into the language as a formal construct.

So what's wrong with this code? Nothing at face value. Maybe it could be
refactored into something less verbose, but it's functional and fairly
straightforward. In the beginning it served our app quite well. But I came to
this code last week because of a bug uncovered by a change in another area of
the app. It turned out that my {% ihighlight ruby %}NilDuck{% endihighlight %} code had gotten stale and not kept up
with changes to the {% ihighlight ruby %}Duck{% endihighlight %} class. Methods had been added to {% ihighlight ruby %}Duck{% endihighlight %}, but not to
{% ihighlight ruby %}NilDuck{% endihighlight %}. Now {% ihighlight ruby %}Duck{% endihighlight %} looks like this:

{% highlight ruby linedivs %}
class Duck < ActiveRecord::Base
  def awake?
    status == 'awake'
  end
  
  def quack
    puts quack_style
  end

  def multi_colored?
    !secondary_color.nil?
  end
end
{% endhighlight %}

And the migration:

{% highlight ruby linedivs %}

class CreateDucks < ActiveRecord::Migration
  def change
    t.string name
    t.string status
    t.integer hunger
    t.string quack_style
    t.string color
    t.string secondary_color
    t.migratory boolean
  end
end
{% endhighlight %}

We don't have equivalent {% ihighlight ruby %}secondary_color{% endihighlight %} and  {% ihighlight ruby %}multi_colored?{% endihighlight %} methods and
our NilDuck started causing errors. Since none of these new methods requirs
special values, I could have just added equivalent getters in NilDuck that
returned {% ihighlight ruby %}nil{% endihighlight %}. But since I'm a lazy programmer, I asked myself how I could
avoid editing this class in the future. I turned to Ruby's {% ihighlight ruby %}method_missing{% endihighlight %}!

In order to understand what my pair and I did here, you need to understand a
little about the way Ruby looks up a method, or message, passed to an object.
When you call a method on a Ruby object, Ruby first looks to see if the method
has been defined on the object instance itself (or more precisely on it's
[eigenclass](http://en.wikipedia.org/wiki/Metaclass)), if it doesn't find it it
will then look in any included modules in reverse include order, then in the
instance methods of the class, and finally in the instance methods of the
{% ihighlight ruby %}Object{% endihighlight %} class, the ultimate ancestor of every object in Ruby. If Ruby still
can't find the method, it starts the search over at our instance, this time
trying to call {% ihighlight ruby %}method_missing{% endihighlight %}. If it can't find a definition for
{% ihighlight ruby %}method_missing{% endihighlight %} somewhere in our inheritance chain, only then will it throw a
{% ihighlight ruby %}NoMethodError{% endihighlight %}.

The {% ihighlight ruby %}method_missing{% endihighlight %} callback gives us the hook we need to handle our, well,
missing methods. Let's refactor our {% ihighlight ruby %}NilDuck{% endihighlight %} to use {% ihighlight ruby %}method_missing{% endihighlight %}:

{% highlight ruby linedivs %}
class NilDuck
  def name
    'Demo Duck'
  end

  def status
    'sleeping'
  end

  def color
    'gray'
  end

  def migratory?
    true
  end

  def method_missing(name, *args)
    Duck.new.respond_to?(name) ? nil : super
  end
end
{% endhighlight %}

See what we did there? We want {% ihighlight ruby %}NilDuck{% endihighlight %} to have the same interface as {% ihighlight ruby %}Duck{% endihighlight %},
so in our {% ihighlight ruby %}method_missing{% endihighlight %} implementation, we first checked to see whether
{% ihighlight ruby %}Duck{% endihighlight %} responds to the method our client code attempted to call. If it does, we
return {% ihighlight ruby %}nil{% endihighlight %}, otherwise we pass the buck to super. Our {% ihighlight ruby %}NilDuck{% endihighlight %} will now
respond to everything that {% ihighlight ruby %}Duck{% endihighlight %} responds to and throw a {% ihighlight ruby %}NoMethodError{% endihighlight %} for
anything that it doesn't respond to. As a bonus, we got to eliminate a lot of
code here.

But what about predicate methods? Well, in Ruby, {% ihighlight ruby %}nil{% endihighlight %} is falsey, so this code
will work correctly in an {% ihighlight ruby %}if/unless/!{% endihighlight %} situation, but what about a situation
in which you might need {% ihighlight ruby %}migratory?{% endihighlight %} to explicitly give you {% ihighlight ruby %}false{% endihighlight %} instead of
{% ihighlight ruby %}nil{% endihighlight %}? What if you are going to pass that {% ihighlight ruby %}true{% endihighlight %} or {% ihighlight ruby %}false{% endihighlight %} along to someone
else as a string? What if you need to feed it into javascript from an erb or
haml template?

{% highlight javascript linedivs %}
{ multiColored: } // !!! Not a valid JSON object, buddy!
{% endhighlight %}

If this {% ihighlight ruby %}duck{% endihighlight %} is our {% ihighlight ruby %}NilDuck{% endihighlight %}, {% ihighlight ruby %}duck.multi_colored?{% endihighlight %} will return {% ihighlight ruby %}nil{% endihighlight %}. When
the template is rendered and the string is interpolated, {% ihighlight ruby %}nil{% endihighlight %}'s {% ihighlight ruby %}to_s{% endihighlight %} method
will be invoked, which will return an empty string instead of {% ihighlight ruby %}'false'{% endihighlight %}. This
will result in a javascript error in the browser:

{% highlight ruby linedivs %}
class NilDuck
  def name
    'Demo Duck'
  end

  def status
    'sleeping'
  end

  def color
    'gray'
  end

  def migratory?
    true
  end

  def method_missing(name, *args)
    super unless Duck.new.respond_to?(name)
    name.ends_with?('?') ? false : nil
  end
end
{% endhighlight %}

Whoops! That's not what we wanted at all! We want {% ihighlight ruby %}'true'{% endihighlight %} or {% ihighlight ruby %}'false'{% endihighlight %} to be
rendered. How can we handle that? Well, we can fall back and explicitly create
a {% ihighlight ruby %}multi_colored?{% endihighlight %} method in our {% ihighlight ruby %}NilDuck{% endihighlight %} that returns {% ihighlight ruby %}false{% endihighlight %}, but we can do
better than that. Let's stay lazy so we don't have to fix this again! Since it
turns out that we don't really want our predicate methods to return just a
falsey value, but {% ihighlight ruby %}false{% endihighlight %} itself. Let's account for that:

{% highlight ruby linedivs %}
class NilDuck
  def name
    'Demo Duck'
  end

  def status
    'sleeping'
  end

  def color
    'gray'
  end

  def migratory?
    true
  end

  def method_missing(name, *args)
    super unless Duck.new.respond_to?(name)
    name.ends_with?('?') ? false : nil
  end
end
{% endhighlight %}

Now if {% ihighlight ruby %}Duck{% endihighlight %} responds to our method and our method ends with '?', {% ihighlight ruby %}NilDuck{% endihighlight %}
will return {% ihighlight ruby %}false{% endihighlight %}, if it doesn't end with '?' it will return {% ihighlight ruby %}nil{% endihighlight %}. Our
template will now render the javascript we expected:

{% highlight javascript linedivs %}
{ multiColored: false }
{% endhighlight %}

You could certainly take this further and abstract out a generic {% ihighlight ruby %}NilObject{% endihighlight %}
for your app, but this serves our needs quite well. For further reading on the
Null Object pattern:
[http://devblog.avdi.org/2011/05/30/null-objects-and-falsiness/]
