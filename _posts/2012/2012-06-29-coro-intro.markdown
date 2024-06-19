---
layout: post
theme:
  name: twitter
title: 【翻译】Coro::Intro文档
category: perl
---
<!-- INDEX BEGIN -->
<div name="index">
<p><a name="__index__"></a></p>

<ul>

	<li><a href="#coro简介">Coro简介</a></li>
	<li><a href="#什么是coro_">什么是Coro？</a></li>
	<li><a href="#协作线程">协作线程</a></li>
	<ul>

		<li><a href="#信号量和其他锁">信号量和其他锁</a></li>
		<li><a href="#频道">频道</a></li>
		<li><a href="#什么是我的_什么是我们的_">什么是我的，什么是我们的？</a></li>
		<li><a href="#调试">调试</a></li>
	</ul>

	<li><a href="#真实世界里的事件循环">真实世界里的事件循环</a></li>
	<ul>

		<li><a href="#真实世界里的文件操作">真实世界里的文件操作</a></li>
		<li><a href="#翻转控制____唤醒函数">翻转控制 —— 唤醒函数</a></li>
	</ul>

	<li><a href="#其他模块">其他模块</a></li>
	<li><a href="#作者">作者</a></li>
</ul>

<hr name="index" />
</div>
<!-- INDEX END -->

<p>
</p>
<h1><a name="coro简介">Coro简介</a></h1>
<p>这个教程准备给你介绍Coro模块家族的最主要的几个特性。</p>
<p>本文首先介绍一些基础概念，然后简单的概述一下Coro家族的情况。</p>
<p>
</p>
<hr />
<h1><a name="什么是coro_">什么是Coro？</a></h1>
<p>Coro最早是作为一个协程的简单实现的模块开始的。它允许你捕获当前的运行点并且跳到另一个点去，又随时可以再跳回来。作为一种非局部的跳转，和C语言里的<code>setjmp</code>/<code>longjmp</code>没什么不同。这就是<a href="/Coro/State.html">the Coro::State manpage</a>模块。</p>
<p>这有一个很天然的应用场合，就是在协作线程中内置一个调度器和结果集，这也是当前Coro最主要的应用场景。很多文档和论文把这些“协作线程(cooperative threads)”叫做“协程(coroutines)”或者更简单的就写成Coros。</p>
<p>一个线程非常像一个精简的Perl解释器或者说进程：跟完整版的Perl解释器不同的地方就是线程并没有自己的局部变量或者代码的名字空间——这些都是共享的。这就意味着当一个线程修改了某个变量(包括通过引用修改任何值)时，其他线程如果使用同样的变量或者值时会立刻发现这个改变。</p>
<p>协作的意思，就是这些线程在涉及到CPU使用的时候必须相互配合——只有一个线程可以真正拥有CPU，如果有别的线程要用，当前运行的这个就要让出。后来的线程可以显式的调用函数来完成这个工作，也可以隐式的等待资源释放(比如信号量或者IO请求的完成)。这种线程模型在脚本语言(比如python或者ruby)中非常流行，而且我们这个实现比其他语言里的线程要高效的多。</p>
<p>Perl本身在这方面用词非常模糊——线程“thread”或者“ithread”实际上在别的地方又被叫做进程“process”：这个所谓的Perl线程实际上是在用于windows上的UNIX进程仿真代码。这就是为什么我们说他是进程而不是真的线程的原因。最大的区别就是，在进程和ithread线程之间，变量不是共享的。</p>
<p>
</p>
<hr />
<h1><a name="协作线程">协作线程</a></h1>
<p>Coro模块带给大家协作线程。首先你要<code>use</code>它：</p>
```perl
    use Coro;```
<p>然后要创建线程，你可以使用Coro模块自动导出的<code>async</code>函数：</p>
```perl
    async {print "hello\n";};```
<p>async期望的第一个参数是一个代码块(间接的对象符号)。你也可以传递更多的变量，他们会在执行的时候作为<code>@_</code>数组传递到代码块里面。不过因为是闭包的原因，你可能只需要引用当前可见的任何词法变量都行。</p>
<p>上面那行就已经创建了一个线程，但是如果你保存这行代码到文件里运行，你会发现自己看不到任何输出。</p>
<p>原因就是：虽然你已经创建了线程，这个线程也已经准备好了执行(<code>async</code>会加入到一个所谓的<em>ready queue</em>里)，它却没有得到CPU时间来实际运行代码，因为main函数——实际也是一个一样的线程——一直霸占着CPU直到整个程序运行到结束。所以Coror的线程是协作的，main也要协作起来，要让出CPU来。</p>
<p>要显式的让出CPU，使用<code>cede</code>函数(在其他线程实现里经常被叫做<code>yield</code>)：</p>
```perl
    use Coro;
    async {
       print "hello\n";
   };
    cede;```
<p>运行上面的代码会打印出<code>hello</code>单词然后退出。</p>
<p>看起来不是很有趣，那让我们搞点稍微有趣的程序：</p>
```perl
    use Coro;
    async {
        print "async 1\n";
        cede;
        print "async 2\n";
    };
    print "main 1\n";
    cede;
    print "main 2\n";
    cede;```
<p>运行这个程序会打印出如下结果：</p>
```perl
    main 1
    async 1
    main 2
    async 2```
<p>这个例子很好的说明了它的非局部的跳跃能力：main先打印了第一回，然后释放CPU给其他线程。嗯，确实有其他线程，于是运行并打印“async 1”，然后这个线程也释放掉CPU。这时候只剩下一个线程就是main了，main于是接着运行。</p>
<p>让我们注意这个例子的更多细节部分：<code>async</code>创建一个新线程。所有的新线程开始都处于暂停状态。要运行的话这些线程就需要被放进ready队列，这是<code>async</code>做的第二件事。每次一个线程让出CPU的时候，Coro就会运行一个所谓的调度器<em>scheduler</em>，调度器选择ready队列中的下一个线程，把它从队列里挪出来运行。</p>
<p><code>cede</code>也做两件事情：第一它把一个运行中的线程放进ready队列里；然后它跳转到调度器。这实际上就是让出CPU。不过最终确保了线程被再次运行。</p>
<p>事实上，<code>cede</code>可以这样实现：</p>
```perl
    sub my_cede {
        $Coro::current->ready;
        schedule;
    }```
<p>这里<code>$Coro::current</code>永远都是包含了当前正在运行的线程，而<code>Coro::schedule</code>则是调度器的调用方法。</p>
<p>那如果不把当前线程放进ready队列里就先调用<code>schedule</code>的效果会怎样呢？很简单，调度器就自动找ready队列里下一个队列。而当前队列因为没放进ready队列里，就会一直沉睡直到有别的因素唤醒它。</p>
<p>下面这个例子，把当前线程记录在一个变量里，创建新线程，这样main线程就沉睡过去了。</p>
<p>然后新创建的线程使用rand来决定是否唤醒main线程，用的是之前变量的<code>ready</code>方法。</p>
```perl
    use Coro;
    my $wakeme = $Coro::current;
    async {
        $wakeme->ready if 0.5 > rand;
    };
    schedule;```
<p>现在，你运行这个程序，可能会发生两种情况：<code>async</code>线程唤醒了main，程序正常退出；或者没有唤醒main，得到的是如下提示：</p>
```perl
    FATAL: deadlock detected.
          PID SC  RSS USES Description              Where
     31976480 -C  19k    0 [main::]                 [program:9]
     32223768 UC  12k    1                          [Coro.pm:691]
     32225088 -- 2068    1 [coro manager]           [Coro.pm:691]
     32225184 N-  216    0 [unblock_sub scheduler]  -```
<p>为什么会这样？嗯，当<code>async</code>线程执行到代码块的最后的时候，他就终止了(通过调用<code>Coro::terminate</code>)，然后重新调用调度器。而之前<code>async</code>线程并没有唤醒main线程，ready队列里没有任何线程可用，程序无法继续了。所以当这里明明有线程<em>可以</em>运行(main)却没有<em>ready</em>，Coro最终得到了一个<em>死锁</em>信号——通常这时候你会看到一个所有线程的列表来帮你追踪问题。</p>
<p>然而现在有个非常重要的场景，<em>就是</em>事实上可能确实没有线程是ready的，但在一个事件驱动的程序里，程序依然可以前进。在这种程序里，某些线程肯尼个在等待一个外部事件，比如超时，比如通过socket到达的数据流。</p>
<p>这种场景下，死锁就不是很有用了。这下有个模块叫<a href="/Coro/AnyEvent.html">the Coro::AnyEvent manpage</a>用来集成线程到事件循环里。它配置Coro使得在这种情况下coro并不返回一个错误信息然后<code>die</code>掉，而是继续运行一个事件循环以期待收到哪个事件可以唤醒某些线程。</p>
<p>
</p>
<h2><a name="信号量和其他锁">信号量和其他锁</a></h2>
<p>仅仅依靠<code>ready</code>、<code>cede</code>和<code>schedule</code>来同步线程是非常困难的。尤其是如果同时有很多线程是ready状态的时候。Coro支持一些原语来帮助你更简单的同步线程。第一个就是<a href="/Coro/Semaphore.html">the Coro::Semaphore manpage</a>模块，它实现了信号量计数(二进制的信号量则是<a href="/Coro/Signal.html">the Coro::Signal manpage</a>模块，同样的还有<a href="/Coro/SemaphoreSet.html">the Coro::SemaphoreSet manpage</a>和<a href="/Coro/RWLock.html">the Coro::RWLock manpage</a>模块)。</p>
<p>信号量计数，某种意义上就是存储一个资源的计数。你可以通过调用<code>->down</code>方法来删除、分配、预留一个资源，这个方法会减去一个计数；同样调用<code>->add</code>方法可以添加或释放一个资源，这又增加一个计数。如果计数器值为<code>0</code>，<code>->down</code>方法就没法再减——也就是说被锁住了——线程就必须等待到计数器重新可用为止。</p>
<p>下面是例子：</p>
```perl
    use Coro;
    my $sem = new Coro::Semaphore 0; #初始化的信号是锁住的
    async {
        print "unlocking semaphore\n";
        $sem->up;
    };
    print "trying to lock semaphore\n";
    $sem->down;
    print "we got it!\n";```
<p>这个程序创建一个<em>锁住</em>的信号(计数器为<code>0</code>)并且尝试锁住他(通过<code>down</code>方法减计数)。因为信号量已经耗尽，main线程会被阻塞住直到信号量恢复可用。</p>
<p>这样CPU就被转给了其他可读的线程，这里是用<code>async</code>创建的那个解锁信号量的线程(并且随即就终止了自己)。</p>
<p>既然信号量恢复了，main也就锁住他然后继续执行打印“we got it!”。</p>
<p>信号量计数最常用的地方是锁资源，或者说在使用和访问某个资源时排他。比如，假设有一个很耗内存的函数。你不想让多个线程同时调用这个函数，你可以这样写：</p>
```perl
    my $lock = new Coro::Semaphore; #初始化未锁，默认是1
    sub costly_function {
        $lock->down; #引入锁
        #进行其他操作
        $lock->up; #解锁
    }```
<p>不管有多少线程调用<code>costly_function</code>，只有一个可以运行他的代码块，其他的都在<code>down</code>调用时阻塞。如果你想限定的并发执行是5个，那就创建信号量的时候指定初始值为<code>5</code>.</p>
<p>为什么提到“操作块”？再次强调，Coro的线程是协作的：<code>costly_function</code>不释放CPU，所有的线程都不会运行。如果函数一直不释放，就显得锁有点多余了，不过在和外面的世界打交道的时候，这种情况太罕见了。</p>
<p>现在想想如果代码在<code>down</code>后，<code>up</code>前就<code>die</code>掉了。这导致信号量保持在一个锁的状态，这应该不会是你想要的——所以如果可能失败的地方，都把调用用<code>eval {}</code>包起来。</p>
<p>所以通常你希望在不管是正常还是异常的时候都释放锁的话，这里有个guard方法可能比较有用：</p>
```perl
    my $lock = new Coro::Semaphore; #初始化时未锁定
    sub costly_function {
        my $guard = $lock->guard; # 获取监视
        ... # 开始做需要阻塞的动作
    }```
<p>这个<code>guard</code>方法<code>down</code>掉信号量并返回一个所谓的guard对象。看起来这个对象除了有个引用外啥都不干，不过当所有的引用都完成，比如<code>costly_function</code>返回或抛出异常，它会自动的调用<code>up</code>恢复信号量，绝对不会忘掉滴。哪怕线程收到别的线程发来的<code>cancel</code>命令。</p>
<p>信号量和锁的介绍到此结束。除了<a href="/Coro/Semaphore.html">the Coro::Semaphore manpage</a>和<a href="/Coro/Signal.html">the Coro::Signal manpage</a>，还有读写锁的<a href="/Coro/RWLock.html">the Coro::RWLock manpage</a>和信号集<a href="/Coro/SemaphoreSet.html">the Coro::SemaphoreSet manpage</a>。他们都有自己的文档可查。</p>
<p>
</p>
<h2><a name="频道">频道</a></h2>
<p>信号量很不错，但通常你可能希望通过交换数据来进行通信。当然，你可以继续用锁、数组来通信，不过这里还有更有用的线程间通信抽象模块:<a href="/Coro/Channel.html">the Coro::Channel manpage</a>。频道是UNIX管道的Coro等价实现(也非常接近AmigaOS的消息端口)——你可以从一段放进去东西，然后从另一头读取出来。</p>
<p>下面是一个简单的例子，创建一个线程然后发送数字给它。然后这个线程计算这个数字的平方，通过另一个频道返回给main线程。</p>
```perl
    use Coro;
    my $calculate = new Coro::Channel;
    my $result    = new Coro::Channel;
    async {
      # 无限循环
        while () {
            my $num = $calculate->get; #获取数字
            $num **= 2; #计算平方
            $result->put ($num); #推进结果队列
        }
    };
    for (1, 2, 5, 10, 77) {
        $calculate->put ($_);
        print "$_ ** 2 = ", $result->get, "\n";
    }```
<p>得到结果是：</p>
```perl
    1 ** 2 = 1
    2 ** 2 = 4
    5 ** 2 = 25
    10 ** 2 = 100
    77 ** 2 = 5929```
<p>这里面<code>get</code>和<code>put</code>方法都会阻塞当前线程：<code>get</code>首先检查是否<em>有</em>数据可用，没有就阻塞到数据到达为止。<code>put</code>同样，在频道到“最大容量”的时候阻塞。你不可能存储超过这个特定值的项目，这个值可以再创建频道的时候设置。</p>
<p>在上面的例子中，<code>put</code>不会阻塞，因为频道的默认容量是很高的。所以for循环首先put数据到频道里，然后开始试图<code>get</code>结果。这时候因为async线程还没有put东西出来(第一次迭代的时候他还没运行)，result频道是空的，所以main线程在这里阻塞住了。</p>
<p>这时候唯一一个可运行的线程就是算平方的这个，于是它会被唤醒，<code>get</code>数据，然后计算平方，put到result频道，就此唤醒main线程，然后他继续运行，唤醒其他线程进入ready队列，就这样。</p>
<p>只有当async线程是从calculate频道<code>get</code>下一个数字的时候，他才会阻塞住(因为现在这个频道里没数据)然后main线程开始继续运行。依次类推。</p>
<p>这说明了Coro的一个总体原则：一个线程<em>只</em>在万不得已的时候才会阻塞。不管是Coro模块本身还是他的任一子模块，都是如此。因为他们在等待某些事件的发生。</p>
<p>不过小心了：当多个线程往<code>$calculate</code>放数据然后从<code>$result</code>里读出来的时候，他们可分不清楚谁是谁的。解决办法是用信号量，或者不单单发送数字，也发送自己专属的result频道。</p>
<p>
</p>
<h2><a name="什么是我的_什么是我们的_">什么是我的，什么是我们的？</a></h2>
<p>到底什么构成了线程？显然它包含有一个当前的执行点。不那么显然的，它还得有局部变量。是的，每个线程都要自己的一组局部变量。</p>
<p>想知道为什么这点是必须的么，看看下面这个例子吧：</p>
```perl
    use Coro;
    sub printit {
        my ($string) = @_;
        cede;
        print $string;
    }
    async { printit "Hello, " };
    async { printit "World!\n" };
    cede; cede;```
<p>上面的代码最终打印的是<code>Hello, World!\n</code>。如果<code>printit</code>没有自己每个线程独立的<code>$string</code>变量，那打印的结果应该是<code>World!\nWorld!\n</code>。这绝对不是你想要的，而且会给线程的使用造成极大的麻烦。</p>
<p>为了让事情变的更顺利些，有不少东西都是线程独立的：</p>
<dl>
<dt><strong><a name="________和正则表达式的捕获变量________1__2等等" class="item">$_，@_，$@和正则表达式的捕获变量，$&amp;，%+，$1，$2等等</a></strong></dt>

<dd>
<p><code>$_</code>用于局部变量，每个线程都是独立的(<code>$1</code>，<code>$2</code>之类的也一样)；</p>
<p><code>@_</code>包括了参数，类似词法变量，也必须是线程独立的；</p>
<p><code>$@</code>不那么必须，但是独立的话会很好用。</p>
</dd>
<dt><strong><a name="__和默认的输出文件句柄" class="item">$/和默认的输出文件句柄</a></strong></dt>

<dd>
<p>线程在做IO的时候经常是阻塞的，而<code>$/</code>就是在读取每行的时候起作用，如果它是个共享变量，事情会很不方便。
默认输出文件句柄(参见<code>select</code>)的情况比较复杂：有时候全局的好，有时候线程独立的好。不过看起来后面这种情况更多一些，所以还是线程独立的了。</p>
</dd>
<dt><strong><a name="_sig___die___和_sig___warn___" class="item">$SIG{__DIE__}和$SIG{__WARN__}</a></strong></dt>

<dd>
<p>如果这两不是线程独立的话，下面这种常见的构造就没法协程切换了。</p>
```perl
        eval {
            local $SIG{__DIE__} = sub { ... };
            ...
        };```
<p>既然异常处理是线程独立的，那么这些变量自然也需要如此了。</p>
</dd>
<dt><strong><a name="一些其他的深奥的玩意儿" class="item">一些其他的深奥的玩意儿</a></strong></dt>

<dd>
<p>比如说<code>$^H</code>变量就是线程独立的。很多类似这样额外的线程独立的东西不会直接被Perl访问，你通常不会注意到这些。</p>
</dd>
</dl>
<p>其他的东西都是线程间共享的。比如全局变量<code>$a</code>和<code>$b</code>。当你使用sort的时候，这两个变量变成特殊变量，然后如果你在排序的时候切换线程，或许结果会让你大吃一惊的。</p>
<p>另外一些<code>$!</code>，errno，<code>$.</code>，输入行号，<code>$,</code>，<code>$\</code>，<code>$"</code>和很多很多其他的特殊变量都是共享的。</p>
<p>虽然有些时候把他们局部化也不错，但一是他们用的不广泛，二是局部化的工作蛮困难的。</p>
<p>总之，如果未来发现哪个共享变量给Coro造成问题了，我们就可能把它改成线程独立的。</p>
<p>
</p>
<h2><a name="调试">调试</a></h2>
<p>有时候查出每个线程在做什么或者哪个线程出现在什么地方是蛮有用的。<a href="/Coro/Debug.html">the Coro::Debug manpage</a>模块就有这么一个方法，让你打印出一个和ps命令结果很像的列表——你可以在Coro检测到死锁前就查看。</p>
<p>使用方法如下：</p>
```perl
    use Coro::Debug;
    Coro::Debug::command "ps";```
<p>还记得上面求平方的例子吧？在<code>$calculate->get</code>后面运行ps方法，然后就会输出类似这样的结果：</p>
<pre>
        PID SC  RSS USES Description              Where
    8917312 -C  22k    0 [main::]                 [introscript:20]
    8964448 N-  152    0 [coro manager]           -
    8964520 N-  152    0 [unblock_sub scheduler]  -
    8591752 UC  152    1                          [introscript:12]
   11546944 N-  152    0 [EV idle process]        -
</pre>
<p>有趣的是后台运行的线程比我们想象中的要多。除掉这些额外的线程，main线程的pid是<code>8917312</code>，而<code>async</code>启动的线程的pid是<code>8591752.</code></p>
<p>后者也是唯一一个没有描述的线程，因为我们没有设置这个。设置方法就是<code>$Coro::current->{desc}</code>；</p>
```perl
    async {
        $Coro::current->{desc} = "cruncher";
        ...
    };```
<p>在调试程序或者使用<a href="/Coro/Debug.html">the Coro::Debug manpage</a>的交互式shell的时候这个可能比较有用。</p>
<p>
</p>
<hr />
<h1><a name="真实世界里的事件循环">真实世界里的事件循环</a></h1>
<p>Coro强烈希望运行在一个事件驱动的程序里。事实上真实情况的Coro程序都是结合事件驱动技术或者多线程技术的。利用Coro也很方便就在这两个世界里做到很好的效果。</p>
<p>Coro可以通过<em>AnyEvent</em>模块(查看<a href="/Coro/AnyEvent.html">the Coro::AnyEvent manpage</a>的更多细节)自动集成到任何事件循环里，也可以接受<em>EV</em>和<em>Event</em>模块的特殊方法。</p>
<p>下面是一个简单的finger客户端，可以使用任何<em>AnyEvent</em>的事件循环：</p>
```perl
    use Coro;
    use Coro::Socket;
    sub finger {
        my ($user, $host) = @_;
        my $fh = new Coro::Socket PeerHost => $host, PeerPort => "finger"
            or die "$user\@$host: $!";
        print $fh "$user\n";
        print "$user\@$host: $_" while &lt;$fh>;
        print "$user\@$host: done\n";
    }
    #验证几个账号
    for (
        (async { finger "abc", "cornell.edu" }),
        (async { finger "sebbo", "world.std.com" }),
        (async { finger "trouble", "noc.dfn.de" }),
    ) {
        $_->join; #等待结果
    }```
<p>这里又有些新东西。首先是<a href="/Coro/Socket.html">the Coro::Socket manpage</a>。这个模块的工作方式和<a href="/IO/Socket/INET.html">the IO::Socket::INET manpage</a>一样，除了它是协程的。也就是说，<a href="/IO/Socket/INET.html">the IO::Socket::INET manpage</a>在等待网络的时候会阻塞整个进程——就是说说所有线程都被阻塞了，这显然是不可取的。</p>
<p>另一方面，<a href="/Coro/Socket.html">the Coro::Socket manpage</a>却知道在等待网络的时候让出CPU给其他线程。这使得并发执行变得可能了。</p>
<p>另一个新东西是<code>join</code>方法：在这个例子里我们想要的就是启动三个<code>async</code>线程然后完成工作后退出。这可以用信号量计数，但是直接同步等待他们<code>terminate</code>更简单一些，这正是<code>join</code>方法做的。</p>
<p>无所谓三个<code>async</code>是不是按照他们<code>join</code>的顺序结束的——当线程还在运行的时候，join单纯就是等待。如果线程终止，他就获取返回值。</p>
<p>如果你之前有事件驱动编程的经验，你会发现上面的程序不太遵循常规的模式，也就是开始一些工作，然后运行事件驱动比如<code>EV::loop</code>。</p>
<p>事实上，重要程序都遵从这个模式，使用Coro也一样，所以和EV一起时Coro程序看起来是这样的：</p>
```perl
    use EV;
    use Coro;
    #开始协程或者事件句柄
    EV::loop; #然后循环```
<p>还有，为了调试，经常写成这样：</p>
```perl
    use EV;
    use Coro::Debug;
    my $shell = new_unix_server Coro::Debug "/tmp/myshell";
    EV::loop; #循环```
<p>这个程序在运行的同时会在UNIX套接字<em class="file">/tmp/myshell</em>上创建一个交互式shell。你可以用<em class="file">socat</em>程序访问它：</p>
<pre>
    # socat readline /tmp/myshell
    coro debug session. use help for more info
    &gt; ps
            PID SC  RSS USES Description              Where
      136672312 RC  19k 177k [main::]                 [myprog:28]
      136710424 -- 1268   48 [coro manager]           [Coro.pm:349]
    &gt; help
    ps [w|v]                show the list of all coroutines (wide, verbose)
    bt &lt;pid&gt;                show a full backtrace of coroutine &lt;pid&gt;
    eval &lt;pid&gt; &lt;perl&gt;       evaluate &lt;perl&gt; expression in context of &lt;pid&gt;
    trace &lt;pid&gt;             enable tracing for this coroutine
    untrace &lt;pid&gt;           disable tracing for this coroutine
    kill &lt;pid&gt; &lt;reason&gt;     throws the given &lt;reason&gt; string in &lt;pid&gt;
    cancel &lt;pid&gt;            cancels this coroutine
    ready &lt;pid&gt;             force &lt;pid&gt; into the ready queue
    &lt;anything else&gt;         evaluate as perl and print results
    &lt;anything else&gt; &amp;       same as above, but evaluate asynchronously
                            you can use (find_coro &lt;pid&gt;) in perl expressions
                            to find the coro with the given pid, e.g.
                            (find_coro 9768720)-&gt;ready
    loglevel &lt;int&gt;          enable logging for messages of level &lt;int&gt; and lower
    exit                    end this session</pre>
<p>好吧，微软用户可以使用<code>new_tcp_server</code>构造器。</p>
<p>
</p>
<h2><a name="真实世界里的文件操作">真实世界里的文件操作</a></h2>
<p>磁盘IO一般比网络IO快很多，但可能占用很长时间，这期间CPU本可以做其他的事情，现在却只能做一样。</p>
<p>幸运的是，CPAN上的<a href="/IO/AIO.html">the IO::AIO manpage</a>模块允许你把这些IO调用移到后台，而在前台做更有用的工作。这是基于事件/回调的，不过Coro很好的包装了它，叫做<a href="/Coro/AIO.html">the Coro::AIO manpage</a>模块，你可以在线程里很自然的使用它的函数：</p>
```perl
    use Fcntl;
    use Coro::AIO;
    my $fh = aio_open "$filename~", O_WRONLY | O_CREAT, 0600
        or die "$filename~: $!";
    aio_write $fh, 0, (length $data), $data, 0;
    aio_fsync $fh;
    aio_close $fh;
    aio_rename "$filename~", "$filename";```
<p>上面创建一个新文件，写入数据，同步到磁盘，然后自动的改成新的副本。</p>
<p>
</p>
<h2><a name="翻转控制____唤醒函数">翻转控制 —— 唤醒函数</a></h2>
<p>最后我说说翻转控制。这个控制指谁通知谁，谁在程序的控制内。在这个程序中，main程序就在控制中，并且传递这个控制给他调用的所有函数：</p>
```perl
    use LWP;
    #转移控制给get
    my $res = get "http://example.org/";
    #控制权返回给我们了
    print $res;```
<p>当你切换到事件驱动程序的时候，不再是“我调用它”，“他调用我”这样——而是标题所说的翻转控制：</p>
```perl
    use AnyEvent::HTTP;
    #不用交出控制权太久，http_get立刻返回了
    http_get "http://example.org/", sub {
        print $_[0];
    };
    #我们继续拥有控制权并且可以做其他事情了```
<p>基于事件的编程很好，不过有时间它只是更简单的码字罢了，因为不用回调可以写得很像线性的样式。Coro也提供了一些特殊的函数来减少敲键盘的功夫：</p>
```perl
    use AnyEvent::HTTP;
    #不用交出控制权太久，http_get立刻返回了
    http_get "http://example.org/", Coro::rouse_cb;
    #我们继续拥有控制权并且可以做其他事情了
    #相当于等待
    my ($res) = Coro::rouse_wait;```
<p><code>Coro::rouse_cb</code>创建并返回一个特殊的回调。你可以把它传递给任意希望有回调的函数。</p>
<p><code>Coro::rouse_wait</code>等待(阻塞当前线程)最近创建的回调被调用，然后返回传给它的所有数据。</p>
<p>这两个函数允许你<em>机械的</em>翻转控制，由绝大多数基于事件的库使用的"基于回调"的样式变成"阻塞式"的样子，绝对如你所愿。</p>
<p>范例很简单，原先这样写：</p>
```perl
    some_func ..., sub {
        my @res = @_;
        ...
    };```
<p>现在这样写：</p>
```perl
    some_func ..., Coro::rouse_cb;
    my @res = Coro::rouse_wait;
    ...```
<p>基于回调的接口很丰富，而这个唤醒函数允许你用一种更方便的方式来使用它们。</p>
<p>
</p>
<hr />
<h1><a name="其他模块">其他模块</a></h1>
<p>这篇介绍里只是提到了很少的几个方法和模块。Coro有很多其他的函数(参见<em>Coro</em>的文档)和模块(在<em>Coro</em>文档的<code>SEE ALSO</code>区域)。</p>
<p>值得注意的有<a href="/Coro/LWP.html">the Coro::LWP manpage</a> (并发LWP请求，不过单纯论HTTP的话，<a href="/AnyEvent/HTTP.html">the AnyEvent::HTTP manpage</a>是更好的替代选择)，<a href="/Coro/BDB.html">the Coro::BDB manpage</a>，当你需要异步数据库的时候可用，<a href="/Coro/Handle.html">the Coro::Handle manpage</a>，当你需要在协程中使用文件句柄(通常访问<code>STDIN</code>和<code>STDOUT</code>)和<a href="/Coro/EV.html">the Coro::EV manpage</a>，优化的<em>EV</em>接口(<a href="/Coro/AnyEvent.html">the Coro::AnyEvent manpage</a>自动使用这个)。</p>
<p>有很多Coro相关的模块(参见i<a href="http://search.cpan.org/search?query=Coro&mode=module">http://search.cpan.org/search</a>)可能对解决你的问题有帮助。而且因为Coro和AnyEvent结合的很好，你也很容易就可以适应现有的AnyEvent模块(参见<a href="http://search.cpan.org/search?query=AnyEvent&mode=module">http://search.cpan.org/search</a>)。</p>
<p>
</p>
<hr />
<h1><a name="作者">作者</a></h1>
<pre>
    Marc Lehmann &lt;schmorp@schmorp.de>
    <a href="http://home.schmorp.de/">http://home.schmorp.de/</a>
</pre>

